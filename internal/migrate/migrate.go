// Package migrate converts a v1 track root to the v2 layout and back.
//
// v1 → v2:
//   - phases/<NN-slug>/ moves to units/legacy-<NN-slug>/ (or units/<issue key> when unit.yaml names one);
//     its v1 unit.yaml is kept byte-for-byte under legacy/unit-yaml/ and a v2 unit.yaml is written.
//   - The shared ledgers (state.md, lineage.md, human-decisions.md, guardrail-log.md, risks.md,
//     gate-history.json) move to legacy/ unchanged and are converted into one event file per record.
//     Event ids are deterministic (time from the record, entropy from its text), so migrating twice
//     writes identical files. Imported decisions are marked authenticated:false.
//
// v2 → v1 restores the originals byte-for-byte. Units and events created after the migration have no
// v1 original: units become phases/NN-<id>/ and new events are appended to lineage.md as lines.
package migrate

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"

	"github.com/manojkvel/sdlc_central/internal/ids"
	"github.com/manojkvel/sdlc_central/internal/ledger"
	"github.com/manojkvel/sdlc_central/internal/track"
	"github.com/manojkvel/sdlc_central/internal/unit"
	"gopkg.in/yaml.v3"
)

// Ledgers are the v1 shared files that move to legacy/.
var Ledgers = []string{"state.md", "lineage.md", "human-decisions.md", "guardrail-log.md", "risks.md", "gate-history.json"}

// Report says what a migration did (or would do, on a dry run).
type Report struct {
	Units    map[string]string // v1 phase dir → unit id
	Events   int
	ByType   map[string]int
	Moved    []string
	DryRun   bool
	Warnings []string
}

func (r Report) String() string {
	var b strings.Builder
	verb := "Migrated"
	if r.DryRun {
		verb = "Would migrate"
	}
	fmt.Fprintf(&b, "%s %d unit(s) and %d event(s).\n", verb, len(r.Units), r.Events)
	keys := make([]string, 0, len(r.Units))
	for k := range r.Units {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	for _, k := range keys {
		fmt.Fprintf(&b, "  phases/%s → units/%s\n", k, r.Units[k])
	}
	types := make([]string, 0, len(r.ByType))
	for k := range r.ByType {
		types = append(types, k)
	}
	sort.Strings(types)
	for _, k := range types {
		fmt.Fprintf(&b, "  %-20s %d\n", k, r.ByType[k])
	}
	for _, w := range r.Warnings {
		fmt.Fprintf(&b, "  warning: %s\n", w)
	}
	return b.String()
}

// ToV2 migrates t (layout 1) to layout 2.
func ToV2(t track.Track, dryRun bool) (Report, error) {
	r := Report{Units: map[string]string{}, ByType: map[string]int{}, DryRun: dryRun}
	if t.Layout != 1 {
		return r, fmt.Errorf("track at %s is layout %d, not 1", t.Root, t.Layout)
	}
	phases, _ := os.ReadDir(filepath.Join(t.Root, "phases"))
	legacyToUnit := map[string]string{}
	for _, p := range phases {
		if !p.IsDir() {
			continue
		}
		id := ids.LegacyUnit(p.Name())
		if u, err := unit.Load(filepath.Join(t.Root, "phases", p.Name())); err == nil && u.IssueKey != "" {
			if k, err := ids.NormalizeUnit(u.IssueKey); err == nil {
				id = k
			}
		}
		legacyToUnit[p.Name()] = id
		r.Units[p.Name()] = id
	}
	events, warns := convert(t, legacyToUnit)
	r.Warnings = append(r.Warnings, warns...)
	for _, e := range events {
		r.ByType[e.Type]++
	}
	r.Events = len(events)
	if dryRun {
		return r, nil
	}

	// 1. move units, keeping the v1 unit.yaml bytes
	for p, id := range legacyToUnit {
		src := filepath.Join(t.Root, "phases", p)
		orig, err := os.ReadFile(filepath.Join(src, "unit.yaml"))
		if err != nil && !errors.Is(err, os.ErrNotExist) {
			return r, err
		}
		if err := os.MkdirAll(t.UnitsDir(), 0o755); err != nil {
			return r, err
		}
		if err := os.Rename(src, t.UnitDir(id)); err != nil {
			return r, err
		}
		r.Moved = append(r.Moved, "phases/"+p)
		if orig != nil {
			if err := writeFile(filepath.Join(t.LegacyDir(), "unit-yaml", p+".yaml"), orig); err != nil {
				return r, err
			}
		}
		var v1 map[string]any
		_ = yaml.Unmarshal(orig, &v1)
		nu := unit.Unit{ID: id, LegacyID: p}
		if v1 != nil {
			nu.Name, _ = v1["name"].(string)
			nu.Profile, _ = v1["profile"].(string)
			if tier, ok := v1["tier"].(int); ok {
				nu.Tier = tier
			}
			nu.Request, _ = v1["request"].(string)
			nu.VerifyCommand, _ = v1["verify_command"].(string)
			nu.LegacyUOW, _ = v1["id"].(string)
			if rs, ok := v1["repos"].([]any); ok {
				for _, x := range rs {
					if s, ok := x.(string); ok {
						nu.Repos = append(nu.Repos, s)
					}
				}
			}
		}
		if err := unit.Save(t.UnitDir(id), nu); err != nil {
			return r, err
		}
	}
	if len(phases) > 0 {
		_ = os.Remove(filepath.Join(t.Root, "phases")) // only when empty
	}
	// 2. move the shared ledgers to legacy/
	for _, f := range Ledgers {
		src := filepath.Join(t.Root, f)
		if _, err := os.Stat(src); err != nil {
			continue
		}
		if err := os.MkdirAll(t.LegacyDir(), 0o755); err != nil {
			return r, err
		}
		if err := os.Rename(src, filepath.Join(t.LegacyDir(), f)); err != nil {
			return r, err
		}
		r.Moved = append(r.Moved, f)
	}
	// 3. write events, then mark the layout
	for _, e := range events {
		if _, err := ledger.Write(t.EventsDir(), e); err != nil && !errors.Is(err, ledger.ErrExists) {
			return r, err
		}
	}
	if err := writeFile(filepath.Join(t.Root, "layout-version"), []byte("2\n")); err != nil {
		return r, err
	}
	return r, nil
}

// ToV1 reverses ToV2. Originals come back byte-for-byte; post-migration work is rendered into v1 form.
func ToV1(t track.Track) (Report, error) {
	r := Report{Units: map[string]string{}, ByType: map[string]int{}}
	if t.Layout != 2 {
		return r, fmt.Errorf("track at %s is layout %d, not 2", t.Root, t.Layout)
	}
	events, err := ledger.Read(t.EventsDir(), "")
	if err != nil {
		return r, err
	}
	var fresh []ledger.Event
	for _, e := range events {
		if _, imported := e.Data["legacy_source"]; !imported {
			fresh = append(fresh, e)
		}
	}
	// 1. ledgers back to the root
	for _, f := range Ledgers {
		src := filepath.Join(t.LegacyDir(), f)
		if _, err := os.Stat(src); err != nil {
			continue
		}
		if err := os.Rename(src, filepath.Join(t.Root, f)); err != nil {
			return r, err
		}
		r.Moved = append(r.Moved, f)
	}
	// 2. units back to phases/
	entries, _ := os.ReadDir(t.UnitsDir())
	next := nextPhaseNumber(t, entries)
	for _, d := range entries {
		if !d.IsDir() {
			continue
		}
		u, err := unit.Load(t.UnitDir(d.Name()))
		if err != nil {
			return r, err
		}
		dst := u.LegacyID
		if dst == "" {
			dst = fmt.Sprintf("%02d-%s", next, strings.ToLower(d.Name()))
			next++
			r.Warnings = append(r.Warnings, fmt.Sprintf("unit %s has no v1 original; restored as phases/%s", d.Name(), dst))
		}
		if err := os.MkdirAll(filepath.Join(t.Root, "phases"), 0o755); err != nil {
			return r, err
		}
		if err := os.Rename(t.UnitDir(d.Name()), filepath.Join(t.Root, "phases", dst)); err != nil {
			return r, err
		}
		if orig, err := os.ReadFile(filepath.Join(t.LegacyDir(), "unit-yaml", dst+".yaml")); err == nil {
			if err := os.WriteFile(filepath.Join(t.Root, "phases", dst, "unit.yaml"), orig, 0o644); err != nil {
				return r, err
			}
		}
		r.Units[d.Name()] = dst
	}
	// 3. post-migration events become lineage lines
	if len(fresh) > 0 {
		f, err := os.OpenFile(filepath.Join(t.Root, "lineage.md"), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
		if err != nil {
			return r, err
		}
		for _, e := range fresh {
			fmt.Fprintln(f, LineageLine(e))
		}
		f.Close()
		r.Warnings = append(r.Warnings, fmt.Sprintf("%d event(s) recorded after migration were appended to lineage.md", len(fresh)))
	}
	r.Events = len(fresh)
	for _, p := range []string{t.EventsDir(), t.LegacyDir(), t.UnitsDir(), t.ViewsDir(), filepath.Join(t.Root, "layout-version")} {
		if err := os.RemoveAll(p); err != nil {
			return r, err
		}
	}
	return r, nil
}

func nextPhaseNumber(t track.Track, units []os.DirEntry) int {
	n := 0
	for _, d := range units {
		if u, err := unit.Load(t.UnitDir(d.Name())); err == nil && len(u.LegacyID) >= 2 {
			var k int
			if _, err := fmt.Sscanf(u.LegacyID, "%d-", &k); err == nil && k > n {
				n = k
			}
		}
	}
	return n + 1
}

// LineageLine renders an event as a v1 lineage line.
func LineageLine(e ledger.Event) string {
	subj, sha := "-", "-"
	if e.Subject != nil {
		if e.Subject.Path != "" {
			subj = e.Subject.Path
		}
		if e.Subject.SHA256 != "" {
			sha = e.Subject.SHA256
		}
	}
	detail := e.Unit
	if s, ok := e.Data["stage"].(string); ok {
		detail = s
	} else if g, ok := e.Data["gate"].(string); ok {
		detail = g
	}
	return fmt.Sprintf("%s | %s | %s: %s | %s | sha256:%s | model=%s | sdlc=2.0.0-alpha",
		e.At.UTC().Format(time.RFC3339), e.ID, e.Type, detail, subj, sha, orDash(e.Actor.Login))
}

func orDash(s string) string {
	if s == "" {
		return "-"
	}
	return s
}

func writeFile(p string, b []byte) error {
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		return err
	}
	return os.WriteFile(p, b, 0o644)
}

// ---------- conversion of the v1 ledgers into events ----------

var (
	phaseInPath = regexp.MustCompile(`/phases/([^/]+)/`)
	hdHeader    = regexp.MustCompile(`^### \[(HD-[0-9]+)\] (.*)$`)
	hdTS        = regexp.MustCompile(`^- \*\*Timestamp:\*\* (\S+)`)
	hdDecider   = regexp.MustCompile(`^- \*\*Decider:\*\* (.*) \(([^)]*)\), identity: (\S+)`)
	hdGate      = regexp.MustCompile("^- \\*\\*Gate:\\*\\* `([^`]*)` · \\*\\*Risk:\\*\\* (\\S+) · \\*\\*Phase:\\*\\* `([^`]*)` · \\*\\*Status:\\*\\* (.*)$")
	hdRisk      = regexp.MustCompile("^- \\*\\*Accepted Risk:\\*\\* `([^`]*)`")
)

var verdicts = map[string]string{
	"APPROVED": "approved", "APPROVED W/ RISK": "approved_with_risk", "CHANGES REQUESTED": "changes_requested",
	"VERIFICATION REQUESTED": "verification_requested", "DEFERRED": "deferred", "REJECTED": "rejected",
}

func migrationActor(kind string) ledger.Actor {
	return ledger.Actor{Kind: kind, Login: "migration", Authenticated: false}
}

func convert(t track.Track, legacyToUnit map[string]string) ([]ledger.Event, []string) {
	var out []ledger.Event
	var warns []string
	unitOf := func(phase string) string {
		if id, ok := legacyToUnit[phase]; ok {
			return id
		}
		return ledger.Project
	}
	seq := uint32(0)
	add := func(unitID, typ string, at time.Time, seed string, actor ledger.Actor, subj *ledger.Subject, data map[string]any) {
		data["legacy_source"] = seed[:strings.Index(seed, ":")]
		seq++ // file order is kept for records that share a timestamp
		out = append(out, ledger.Event{V: ledger.Version, ID: ids.DeterministicSeq(at, seq, seed), Unit: unitID, Type: typ,
			At: at.UTC(), Actor: actor, Subject: subj, Data: data})
	}
	parseTime := func(s string) (time.Time, bool) {
		at, err := time.Parse(time.RFC3339, strings.TrimSpace(s))
		return at, err == nil
	}

	// lineage.md
	first := map[string]time.Time{}
	eachLine(filepath.Join(t.Root, "lineage.md"), func(n int, line string) {
		f := strings.Split(line, " | ")
		if len(f) < 5 {
			return
		}
		at, ok := parseTime(f[0])
		if !ok {
			return
		}
		ev, detail, _ := strings.Cut(f[2], ": ")
		art, sha := f[3], strings.TrimPrefix(f[4], "sha256:")
		unitID := ledger.Project
		if m := phaseInPath.FindStringSubmatch("/" + strings.TrimPrefix(art, "/")); m != nil {
			unitID = unitOf(m[1])
		}
		var subj *ledger.Subject
		if art != "-" || (sha != "-" && sha != "") {
			subj = &ledger.Subject{Path: art}
			if sha != "-" {
				subj.SHA256 = sha
			}
		}
		data := map[string]any{"legacy_event": ev, "detail": detail, "ref": f[1]}
		typ := "migration.imported"
		switch {
		case ev == "stage.entered":
			typ, data["stage"] = "stage.entered", detail
		case strings.HasPrefix(ev, "evidence."):
			typ = "evidence.recorded"
		}
		add(unitID, typ, at, fmt.Sprintf("lineage.md:%d:%s", n, line), migrationActor("agent"), subj, data)
		if unitID != ledger.Project {
			if ft, ok := first[unitID]; !ok || at.Before(ft) {
				first[unitID] = at
			}
		}
	})

	// human-decisions.md: one decision.recorded per HD record
	var cur map[string]string
	flush := func() {
		if cur == nil {
			return
		}
		at, ok := parseTime(cur["ts"])
		if !ok {
			warns = append(warns, "decision "+cur["hd"]+" has no readable timestamp; skipped")
			cur = nil
			return
		}
		v := verdicts[strings.TrimSpace(cur["status"])]
		if v == "" {
			v = strings.ToLower(strings.ReplaceAll(strings.TrimSpace(cur["status"]), " ", "_"))
		}
		data := map[string]any{"gate": cur["gate"], "verdict": v, "risk_level": cur["risk"], "legacy_hd": cur["hd"],
			"decision": cur["title"], "role": cur["role"], "decider": cur["decider"], "legacy_identity": cur["identity"]}
		if cur["accepted_risk"] != "" {
			data["accepted_risk"] = cur["accepted_risk"]
		}
		actor := ledger.Actor{Kind: "human", Login: cur["decider"], Authenticated: false}
		add(unitOf(cur["phase"]), "decision.recorded", at, "human-decisions.md:"+cur["hd"]+":"+cur["ts"], actor, nil, data)
		cur = nil
	}
	eachLine(filepath.Join(t.Root, "human-decisions.md"), func(n int, line string) {
		if m := hdHeader.FindStringSubmatch(line); m != nil {
			flush()
			cur = map[string]string{"hd": m[1], "title": m[2]}
			return
		}
		if cur == nil {
			return
		}
		switch {
		case hdTS.MatchString(line):
			cur["ts"] = hdTS.FindStringSubmatch(line)[1]
		case hdDecider.MatchString(line):
			m := hdDecider.FindStringSubmatch(line)
			cur["decider"], cur["role"], cur["identity"] = m[1], m[2], m[3]
		case hdGate.MatchString(line):
			m := hdGate.FindStringSubmatch(line)
			cur["gate"], cur["risk"], cur["phase"], cur["status"] = m[1], m[2], m[3], m[4]
		case hdRisk.MatchString(line):
			cur["accepted_risk"] = hdRisk.FindStringSubmatch(line)[1]
		case strings.HasPrefix(line, "## "):
			flush()
		}
	})
	flush()

	// guardrail-log.md
	eachLine(filepath.Join(t.Root, "guardrail-log.md"), func(n int, line string) {
		c := tableCells(line)
		if len(c) < 5 {
			return
		}
		at, ok := parseTime(c[0])
		if !ok {
			return
		}
		add(unitOf(c[3]), "guardrail.fired", at, fmt.Sprintf("guardrail-log.md:%d:%s", n, line), migrationActor("agent"), nil,
			map[string]any{"hook": c[1], "code": c[2], "detail": c[4]})
	})

	// risks.md (no timestamps in v1: they take the time of the unit's first event, or the file's first lineage event)
	var epoch time.Time
	for _, ft := range first {
		if epoch.IsZero() || ft.Before(epoch) {
			epoch = ft
		}
	}
	if epoch.IsZero() {
		epoch = time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	}
	eachLine(filepath.Join(t.Root, "risks.md"), func(n int, line string) {
		c := tableCells(line)
		if len(c) < 4 || !strings.HasPrefix(c[0], "RISK-") {
			return
		}
		data := map[string]any{"risk": c[0], "text": c[1], "raised_by": c[2], "status": c[3]}
		if len(c) > 4 {
			data["signed_off_by"] = c[4]
		}
		add(ledger.Project, "risk.raised", epoch, fmt.Sprintf("risks.md:%d:%s", n, line), migrationActor("agent"), nil, data)
	})

	// gate-history.json
	if b, err := os.ReadFile(filepath.Join(t.Root, "gate-history.json")); err == nil {
		var gh struct {
			Gates []map[string]any `json:"gates"`
		}
		if json.Unmarshal(b, &gh) == nil {
			for i, g := range gh.Gates {
				ds, _ := g["date"].(string)
				at, ok := parseTime(ds)
				if !ok {
					continue
				}
				phase, _ := g["phase"].(string)
				result := "failed"
				if d, _ := g["decision"].(string); d == "PASS" {
					result = "passed"
				}
				typ, _ := g["type"].(string)
				raw, _ := json.Marshal(g)
				add(unitOf(phase), "gate.evaluated", at, fmt.Sprintf("gate-history.json:%d:%s", i, raw), migrationActor("ci"), nil,
					map[string]any{"gate": typ, "result": result, "dimensions": g["dimensions"]})
			}
		}
	}

	// state.md: an open gate stays open after the migration
	resume := map[string]string{}
	inBlock := false
	eachLine(filepath.Join(t.Root, "state.md"), func(n int, line string) {
		if strings.HasPrefix(line, "## AIDLC_RESUME") {
			inBlock = true
			return
		}
		if inBlock && strings.HasPrefix(line, "## ") {
			inBlock = false
		}
		if inBlock {
			if k, v, ok := strings.Cut(line, ": "); ok {
				resume[k] = strings.TrimSpace(v)
			}
		}
	})
	if g := resume["BLOCKED_GATE"]; g != "" && g != "none" {
		ph := resume["CURRENT_PHASE"]
		at := first[unitOf(ph)]
		if at.IsZero() {
			at = epoch
		}
		add(unitOf(ph), "gate.evaluated", at.Add(time.Millisecond), "state.md:open-gate:"+ph+":"+g, migrationActor("agent"), nil,
			map[string]any{"gate": g, "result": "open", "risk": resume["GATE_RISK"]})
	}

	// one unit.started per migrated unit, at its first event
	phases := make([]string, 0, len(legacyToUnit))
	for p := range legacyToUnit {
		phases = append(phases, p)
	}
	sort.Strings(phases) // map order is random; ids must not be
	for _, phase := range phases {
		id := legacyToUnit[phase]
		at, ok := first[id]
		if !ok {
			at = epoch
		}
		data := map[string]any{"legacy_id": phase}
		if u, err := unit.Load(filepath.Join(t.Root, "phases", phase)); err == nil {
			data["name"], data["profile"], data["tier"] = u.Name, u.Profile, u.Tier
		}
		add(id, "unit.started", at.Add(-time.Millisecond), "unit.started:"+phase, migrationActor("agent"), nil, data)
	}
	ledger.Sort(out)
	return out, warns
}

func eachLine(p string, fn func(n int, line string)) {
	f, err := os.Open(p)
	if err != nil {
		return
	}
	defer f.Close()
	s := bufio.NewScanner(f)
	s.Buffer(make([]byte, 1024*1024), 1024*1024)
	n := 0
	for s.Scan() {
		n++
		fn(n, s.Text())
	}
}

func tableCells(line string) []string {
	line = strings.TrimSpace(line)
	if !strings.HasPrefix(line, "|") || strings.HasPrefix(line, "| ---") || strings.HasPrefix(line, "| :") {
		return nil
	}
	parts := strings.Split(strings.Trim(line, "|"), "|")
	for i := range parts {
		parts[i] = strings.TrimSpace(parts[i])
	}
	return parts
}
