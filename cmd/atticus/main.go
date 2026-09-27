// Command atticus-core is the Go core of Atticus (roadmap milestone M1): the conflict-free ledger,
// per-unit state bound to git branches, and the v1↔v2 track migration. During the compatibility
// period the bash `atticus` CLI hands v2 work to this binary; in M2 it takes over the hooks too.
package main

import (
	"errors"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/manojkvel/sdlc_central/internal/ids"
	"github.com/manojkvel/sdlc_central/internal/ledger"
	"github.com/manojkvel/sdlc_central/internal/migrate"
	"github.com/manojkvel/sdlc_central/internal/state"
	"github.com/manojkvel/sdlc_central/internal/track"
	"github.com/manojkvel/sdlc_central/internal/unit"
	"github.com/manojkvel/sdlc_central/internal/views"
)

var version = "2.0.0-alpha.m1"

const usage = `atticus-core: Atticus core (ledger, units, migration)

  atticus-core layout init                       create a v2 track root here
  atticus-core start <ISSUE-KEY> [--name N] [--tier 1|2|3] [--profile P] [--branch B] [--no-branch]
                                                 start a unit; omit the key for a local unit (u-<ULID>)
  atticus-core status [--unit U]                 the unit's state (default: the unit of this branch)
  atticus-core context [--unit U]               a short digest for an agent (instead of reading .track)
  atticus-core ledger list [--unit U]            events, oldest first
  atticus-core ledger record <type> --unit U [--subject PATH] [key=value ...]
  atticus-core ledger lint [--base REF --head REF]   immutability and schema (CI runs this per PR)
  atticus-core migrate --to v2|v1 [--dry-run] [--force]
                                                 convert the track root layout (reversible; v2 needs --force until M2)
  atticus-core views                             regenerate views/ for v1 readers
  atticus-core version
`

func main() {
	if len(os.Args) < 2 {
		fmt.Print(usage)
		os.Exit(0)
	}
	cwd, _ := os.Getwd()
	var err error
	switch os.Args[1] {
	case "version", "--version":
		fmt.Println("atticus-core", version)
	case "help", "-h", "--help":
		fmt.Print(usage)
	case "layout":
		err = cmdLayout(cwd, os.Args[2:])
	case "start":
		err = cmdStart(cwd, os.Args[2:])
	case "status":
		err = cmdStatus(cwd, os.Args[2:], false)
	case "context":
		err = cmdStatus(cwd, os.Args[2:], true)
	case "ledger":
		err = cmdLedger(cwd, os.Args[2:])
	case "migrate":
		err = cmdMigrate(cwd, os.Args[2:])
	case "views":
		err = cmdViews(cwd)
	default:
		err = fmt.Errorf("unknown command %q (atticus-core help)", os.Args[1])
	}
	if err != nil {
		var ex exitErr
		if errors.As(err, &ex) {
			fmt.Fprintln(os.Stderr, "atticus-core:", ex.msg)
			os.Exit(ex.code)
		}
		fmt.Fprintln(os.Stderr, "atticus-core:", err)
		os.Exit(1)
	}
}

type exitErr struct {
	code int
	msg  string
}

func (e exitErr) Error() string { return e.msg }

func v2(cwd string) (track.Track, error) {
	t, err := track.Find(cwd)
	if err != nil {
		return t, err
	}
	switch t.Layout {
	case 2:
		return t, nil
	case 1:
		return t, exitErr{2, "this track root is layout v1; run: atticus-core migrate --to v2"}
	}
	return t, exitErr{2, "no track root here; run: atticus-core layout init"}
}

func cmdLayout(cwd string, args []string) error {
	if len(args) == 0 || args[0] != "init" {
		return fmt.Errorf("usage: atticus-core layout init")
	}
	t, err := track.Find(cwd)
	if err != nil {
		return err
	}
	if t.Layout == 1 {
		return exitErr{2, "a v1 track root exists; migrate it instead: atticus-core migrate --to v2"}
	}
	for _, d := range []string{t.UnitsDir(), t.EventsDir()} {
		if err := os.MkdirAll(d, 0o755); err != nil {
			return err
		}
	}
	os.WriteFile(t.Root+"/layout-version", []byte("2\n"), 0o644)
	gi := t.Root + "/.gitignore"
	if _, err := os.Stat(gi); err != nil {
		os.WriteFile(gi, []byte("# Generated views and local evidence bodies stay out of git.\nviews/\nunits/*/evidence/**/*.out\nunits/*/evidence/**/*.err\n"), 0o644)
	}
	for _, d := range []string{t.UnitsDir(), t.EventsDir()} {
		keep := d + "/.gitkeep"
		if _, err := os.Stat(keep); err != nil {
			os.WriteFile(keep, nil, 0o644)
		}
	}
	fmt.Println("v2 track root ready:", t.Rel(t.Root))
	return nil
}

func localActor(repo string) ledger.Actor {
	name, _ := gitOut(repo, "config", "user.name")
	return ledger.Actor{Kind: "human", Login: name, Authenticated: false}
}

func localSource(repo string) ledger.Source {
	s := ledger.Source{Host: "local", Branch: state.CurrentBranch(repo)}
	s.Commit, _ = gitOut(repo, "rev-parse", "HEAD")
	return s
}

var slugRe = regexp.MustCompile(`[^a-z0-9]+`)

func slug(s string) string {
	s = strings.Trim(slugRe.ReplaceAllString(strings.ToLower(s), "-"), "-")
	if len(s) > 40 {
		s = strings.TrimRight(s[:40], "-")
	}
	return s
}

func cmdStart(cwd string, args []string) error {
	fs := flag.NewFlagSet("start", flag.ContinueOnError)
	name := fs.String("name", "", "short name")
	tier := fs.Int("tier", 2, "1, 2 or 3")
	profile := fs.String("profile", "feature", "work profile")
	branch := fs.String("branch", "", "branch to create or use")
	noBranch := fs.Bool("no-branch", false, "do not create or switch branches")
	key := ""
	if len(args) > 0 && !strings.HasPrefix(args[0], "-") {
		key, args = args[0], args[1:]
	}
	if err := fs.Parse(args); err != nil {
		return err
	}
	t, err := v2(cwd)
	if err != nil {
		return err
	}
	id := ""
	if key == "" {
		id = ids.NewLocalUnit(time.Now())
	} else if id, err = ids.NormalizeUnit(key); err != nil {
		return exitErr{2, err.Error()}
	}
	if *tier < 1 || *tier > 3 {
		return exitErr{2, "tier must be 1, 2 or 3"}
	}
	if es, _ := ledger.Read(t.EventsDir(), id); len(es) > 0 {
		return exitErr{2, fmt.Sprintf("unit %s is already started; switch to its branch (atticus-core status --unit %s)", id, id)}
	}
	repo := t.Project
	br := state.CurrentBranch(repo)
	if !*noBranch && br != "" {
		want := *branch
		if want == "" {
			want = "feat/" + id
			if *name != "" {
				want += "-" + slug(*name)
			}
		}
		if other := boundElsewhere(repo, id, want); other != "" {
			return exitErr{2, fmt.Sprintf("unit %s is already bound to branch %s", id, other)}
		}
		if br != want {
			if _, err := gitOut(repo, "switch", "-c", want); err != nil {
				if _, err2 := gitOut(repo, "switch", want); err2 != nil {
					return fmt.Errorf("could not create or switch to %s: %v", want, err)
				}
			}
			br = want
		}
		if state.UnitFromBranch(br) != id {
			if err := state.Bind(repo, br, id); err != nil {
				return err
			}
		}
	}
	u := unit.Unit{ID: id, Name: *name, Tier: *tier, Profile: *profile, Branch: br}
	if strings.HasPrefix(id, "ADO-") {
		u.Tracker, u.IssueKey = "ado", id
	} else if !strings.HasPrefix(id, "u-") {
		u.Tracker, u.IssueKey = "jira", id
	}
	if err := unit.Save(t.UnitDir(id), u); err != nil {
		return err
	}
	e := ledger.New(id, "unit.started", localActor(repo))
	e.Source = localSource(repo)
	e.Data = map[string]any{"name": *name, "tier": *tier, "profile": *profile, "branch": br}
	if _, err := ledger.Write(t.EventsDir(), e); err != nil {
		return err
	}
	fmt.Printf("Started %s (tier %d, %s)", id, *tier, *profile)
	if br != "" {
		fmt.Printf(" on branch %s", br)
	}
	fmt.Println(".")
	return nil
}

func boundElsewhere(repo, id, branch string) string {
	out, err := gitOut(repo, "config", "--get-regexp", `^branch\..*\.atticus-unit$`)
	if err != nil {
		return ""
	}
	for _, line := range strings.Split(out, "\n") {
		k, v, ok := strings.Cut(line, " ")
		if !ok || v != id {
			continue
		}
		b := strings.TrimSuffix(strings.TrimPrefix(k, "branch."), ".atticus-unit")
		if b != branch {
			return b
		}
	}
	return ""
}

func resolveUnit(t track.Track, fs *flag.FlagSet, u *string) (string, error) {
	if *u != "" {
		return ids.NormalizeUnit(*u)
	}
	id, br := state.CurrentUnit(t.Project)
	if id == "" {
		if br == "" {
			br = "(no branch)"
		}
		return "", exitErr{2, "no unit for branch " + br + "; pass --unit or start one: atticus-core start <ISSUE-KEY>"}
	}
	return id, nil
}

func cmdStatus(cwd string, args []string, digest bool) error {
	fs := flag.NewFlagSet("status", flag.ContinueOnError)
	uflag := fs.String("unit", "", "unit id")
	if err := fs.Parse(args); err != nil {
		return err
	}
	t, err := v2(cwd)
	if err != nil {
		return err
	}
	id, err := resolveUnit(t, fs, uflag)
	if err != nil {
		return err
	}
	es, err := ledger.Read(t.EventsDir(), id)
	if err != nil {
		return err
	}
	if len(es) == 0 {
		return exitErr{2, "unit " + id + " has no events; start it: atticus-core start " + id}
	}
	s := state.Fold(id, es)
	if digest {
		// Kept short on purpose: agents read this instead of the ledger (token budget ~300).
		fmt.Printf("unit %s · stage %s · tier %d", s.ID, s.Stage, s.Tier)
		if s.OpenGate != "" {
			fmt.Printf(" · OPEN GATE %s (%s risk): do not change code; the decision is made in the pull request", s.OpenGate, s.GateRisk)
		}
		fmt.Printf("\nnext: %s\n", s.NextAction())
		n := len(es)
		from := n - 5
		if from < 0 {
			from = 0
		}
		fmt.Println("recent:")
		for _, e := range es[from:] {
			fmt.Printf("  %s %s %s\n", e.At.Format("2006-01-02 15:04"), e.Type, summary(e))
		}
		return nil
	}
	fmt.Printf("Unit:        %s\n", s.ID)
	if s.Name != "" {
		fmt.Printf("Name:        %s\n", s.Name)
	}
	fmt.Printf("Stage:       %s\nTier:        %d\n", s.Stage, s.Tier)
	if s.OpenGate != "" {
		fmt.Printf("Open gate:   %s (%s risk)\n", s.OpenGate, s.GateRisk)
	} else {
		fmt.Println("Open gate:   none")
	}
	fmt.Printf("Decisions:   %d", len(s.Decisions))
	auth := 0
	for _, d := range s.Decisions {
		if d.Authenticated {
			auth++
		}
	}
	fmt.Printf(" (%d authenticated)\n", auth)
	risks := make([]string, 0, len(s.OpenRisks))
	for k := range s.OpenRisks {
		risks = append(risks, k)
	}
	sort.Strings(risks)
	fmt.Printf("Open risks:  %s\n", orNone(strings.Join(risks, ", ")))
	fmt.Printf("Evidence:    %d run(s) · guardrail blocks: %d\n", s.Evidence, s.Guardrails)
	fmt.Printf("Next:        %s\n", s.NextAction())
	return nil
}

func summary(e ledger.Event) string {
	for _, k := range []string{"stage", "gate", "verdict", "code", "risk", "legacy_event"} {
		if v, ok := e.Data[k].(string); ok && v != "" {
			if k == "gate" {
				if vd, ok := e.Data["verdict"].(string); ok {
					return v + " " + vd
				}
				if r, ok := e.Data["result"].(string); ok {
					return v + " " + r
				}
			}
			return v
		}
	}
	return ""
}

func orNone(s string) string {
	if s == "" {
		return "none"
	}
	return s
}

func cmdLedger(cwd string, args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("usage: atticus-core ledger list|record|lint")
	}
	t, err := v2(cwd)
	if err != nil {
		return err
	}
	switch args[0] {
	case "list":
		fs := flag.NewFlagSet("list", flag.ContinueOnError)
		u := fs.String("unit", "", "unit id")
		if err := fs.Parse(args[1:]); err != nil {
			return err
		}
		es, err := ledger.Read(t.EventsDir(), *u)
		if err != nil {
			return err
		}
		for _, e := range es {
			fmt.Printf("%s %s %-9s %-19s %s\n", e.At.Format(time.RFC3339), e.ID, e.Unit, e.Type, summary(e))
		}
		return nil
	case "record":
		if len(args) < 2 {
			return fmt.Errorf("usage: atticus-core ledger record <type> --unit U [--subject PATH] [key=value ...]")
		}
		typ := args[1]
		fs := flag.NewFlagSet("record", flag.ContinueOnError)
		u := fs.String("unit", "", "unit id, or _project")
		subj := fs.String("subject", "", "artifact path")
		if err := fs.Parse(args[2:]); err != nil {
			return err
		}
		id := *u
		if id != ledger.Project {
			if id, err = resolveUnit(t, fs, u); err != nil {
				return err
			}
		}
		e := ledger.New(id, typ, localActor(t.Project))
		e.Source = localSource(t.Project)
		e.Data = map[string]any{}
		for _, kv := range fs.Args() {
			k, v, ok := strings.Cut(kv, "=")
			if !ok {
				return exitErr{2, "data must be key=value, got " + kv}
			}
			if n, err := strconv.Atoi(v); err == nil {
				e.Data[k] = n
			} else {
				e.Data[k] = v
			}
		}
		if *subj != "" {
			e.Subject = &ledger.Subject{Path: *subj}
		}
		p, err := ledger.Write(t.EventsDir(), e)
		if err != nil {
			return exitErr{2, err.Error()}
		}
		fmt.Println(t.Rel(p))
		return nil
	case "lint":
		fs := flag.NewFlagSet("lint", flag.ContinueOnError)
		base := fs.String("base", "", "base ref (merge-base side)")
		head := fs.String("head", "HEAD", "head ref")
		if err := fs.Parse(args[1:]); err != nil {
			return err
		}
		rel := t.Rel(t.EventsDir())
		var findings []ledger.Finding
		if *base != "" {
			findings, err = ledger.LintDiff(t.Project, *base, *head, rel)
		} else {
			findings, err = ledger.LintTree(t.EventsDir(), rel)
		}
		if err != nil {
			return err
		}
		for _, f := range findings {
			fmt.Println(f)
		}
		if len(findings) > 0 {
			return exitErr{2, fmt.Sprintf("%d ledger finding(s)", len(findings))}
		}
		fmt.Println("L000 ledger clean")
		return nil
	}
	return fmt.Errorf("unknown ledger command %q", args[0])
}

func cmdMigrate(cwd string, args []string) error {
	fs := flag.NewFlagSet("migrate", flag.ContinueOnError)
	to := fs.String("to", "", "v2 or v1")
	dry := fs.Bool("dry-run", false, "report only")
	force := fs.Bool("force", false, "migrate to v2 before the hooks are v2-aware (roadmap M2)")
	if err := fs.Parse(args); err != nil {
		return err
	}
	t, err := track.Find(cwd)
	if err != nil {
		return err
	}
	var r migrate.Report
	switch *to {
	case "v2":
		if !*dry && !*force {
			return exitErr{2, "the bash hooks are not v2-aware until roadmap M2, so a v2 track would switch local enforcement off.\n" +
				"Preview with --dry-run, or pass --force for a pilot or test repository (reverse with --to v1)."}
		}
		r, err = migrate.ToV2(t, *dry)
	case "v1":
		if *dry {
			return exitErr{2, "--dry-run is only supported for --to v2"}
		}
		r, err = migrate.ToV1(t)
	default:
		return exitErr{2, "use --to v2 or --to v1"}
	}
	if err != nil {
		return err
	}
	fmt.Print(r.String())
	if *to == "v2" && !*dry {
		fmt.Println("Commit the result in one commit. Reverse with: atticus-core migrate --to v1")
	}
	return nil
}

func cmdViews(cwd string) error {
	t, err := v2(cwd)
	if err != nil {
		return err
	}
	id, _ := state.CurrentUnit(t.Project)
	if err := views.Write(t, id); err != nil {
		return err
	}
	fmt.Println("views written:", t.Rel(t.ViewsDir()))
	return nil
}

func gitOut(repo string, args ...string) (string, error) {
	cmd := exec.Command("git", args...)
	cmd.Dir = repo
	b, err := cmd.Output()
	return strings.TrimSpace(string(b)), err
}
