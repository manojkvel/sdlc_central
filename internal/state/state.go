// Package state derives a unit's state from its events and binds git branches to units.
//
// v1 kept one global AIDLC_RESUME block in state.md, so a repository could have one active unit
// and every step rewrote a shared file. v2 commits no global state: the current unit comes from
// the branch, and a unit's state is a fold over its own immutable events.
package state

import (
	"fmt"
	"os/exec"
	"regexp"
	"strings"
	"time"

	"github.com/manojkvel/sdlc_central/internal/ids"
	"github.com/manojkvel/sdlc_central/internal/ledger"
)

// Decision is a recorded human decision.
type Decision struct {
	ID            string
	Gate          string
	Verdict       string // approved | approved_with_risk | changes_requested | verification_requested | deferred | rejected
	Actor         ledger.Actor
	At            time.Time
	Authenticated bool
}

// Unit is the folded state of one unit of work.
type Unit struct {
	ID          string
	Name        string
	Tier        int
	Profile     string
	Branch      string
	Started     time.Time
	Stage       string
	OpenGate    string
	GateRisk    string
	Decisions   []Decision
	OpenRisks   map[string]string // risk id → text
	Evidence    int
	Guardrails  int
	Imported    int // events brought over from a v1 track
	LastEventAt time.Time
}

// Fold applies events (sorted by ledger.Sort) to build a unit's state.
func Fold(unitID string, events []ledger.Event) Unit {
	u := Unit{ID: unitID, Stage: "none", OpenRisks: map[string]string{}}
	for _, e := range events {
		if e.Unit != unitID {
			continue
		}
		u.LastEventAt = e.At
		d := e.Data
		switch e.Type {
		case "unit.started":
			u.Started = e.At
			u.Stage = "intake"
			u.Name, _ = str(d, "name")
			u.Profile, _ = str(d, "profile")
			u.Branch, _ = str(d, "branch")
			u.Tier = num(d, "tier")
		case "stage.entered":
			if s, ok := str(d, "stage"); ok {
				u.Stage = s
			}
		case "gate.evaluated":
			g, _ := str(d, "gate")
			switch r, _ := str(d, "result"); r {
			case "open":
				u.OpenGate, _ = str(d, "gate")
				u.GateRisk, _ = str(d, "risk")
			case "passed", "failed", "auto_approved":
				if u.OpenGate == g {
					u.OpenGate, u.GateRisk = "", ""
				}
			}
		case "decision.recorded":
			g, _ := str(d, "gate")
			v, _ := str(d, "verdict")
			u.Decisions = append(u.Decisions, Decision{ID: e.ID, Gate: g, Verdict: v, Actor: e.Actor, At: e.At, Authenticated: e.Actor.Authenticated})
			if u.OpenGate == g && (v == "approved" || v == "approved_with_risk" || v == "rejected") {
				u.OpenGate, u.GateRisk = "", ""
			}
		case "risk.raised":
			if id, ok := str(d, "risk"); ok {
				t, _ := str(d, "text")
				u.OpenRisks[id] = t
			}
		case "risk.closed":
			if id, ok := str(d, "risk"); ok {
				delete(u.OpenRisks, id)
			}
		case "evidence.recorded":
			u.Evidence++
		case "guardrail.fired":
			u.Guardrails++
		case "migration.imported":
			u.Imported++
		}
	}
	return u
}

// NextAction says what should happen next, in words a person can act on.
func (u Unit) NextAction() string {
	switch {
	case u.OpenGate != "":
		return fmt.Sprintf("decide %s (%s risk) in the pull request", u.OpenGate, orDash(u.GateRisk))
	case u.Stage == "none":
		return "start the unit: atticus start <issue-key>"
	case u.Stage == "released" || u.Stage == "done":
		return "nothing: the unit is " + u.Stage
	default:
		return "continue the " + u.Stage + " stage"
	}
}

func orDash(s string) string {
	if s == "" {
		return "unknown"
	}
	return s
}

func str(d map[string]any, k string) (string, bool) {
	v, ok := d[k].(string)
	return v, ok && v != ""
}

func num(d map[string]any, k string) int {
	switch v := d[k].(type) {
	case float64:
		return int(v)
	case int:
		return v
	}
	return 0
}

// ---------- branch binding ----------

var (
	branchKey   = regexp.MustCompile(`(?i)(?:^|/)([A-Z][A-Z0-9]{1,9}-[0-9]{1,9})(?:[-_/]|$)`)
	branchLocal = regexp.MustCompile(`(?:^|/)(u-[0-9a-hjkmnp-tv-z]{26})(?:[-_/]|$)`)
)

// UnitFromBranch extracts a unit id from a branch name such as feat/PAY-142-refund or fix/ado-4567.
func UnitFromBranch(branch string) string {
	if m := branchLocal.FindStringSubmatch(branch); m != nil {
		return m[1]
	}
	if m := branchKey.FindStringSubmatch(branch); m != nil {
		if id, err := ids.NormalizeUnit(m[1]); err == nil {
			return id
		}
	}
	return ""
}

// CurrentBranch returns the checked-out branch, or "" when detached or outside git.
func CurrentBranch(repo string) string {
	out, err := gitOut(repo, "rev-parse", "--abbrev-ref", "HEAD")
	if err != nil || out == "HEAD" {
		return ""
	}
	return out
}

// CurrentUnit resolves the unit for the checked-out branch: an explicit binding
// (git config branch.<b>.atticus-unit) wins over the unit parsed from the branch name.
func CurrentUnit(repo string) (unit, branch string) {
	branch = CurrentBranch(repo)
	if branch == "" {
		return "", ""
	}
	if v, err := gitOut(repo, "config", "--get", "branch."+branch+".atticus-unit"); err == nil && v != "" {
		return v, branch
	}
	return UnitFromBranch(branch), branch
}

// Bind records that branch works on unit (local git config: never committed, never conflicts).
func Bind(repo, branch, unit string) error {
	_, err := gitOut(repo, "config", "branch."+branch+".atticus-unit", unit)
	return err
}

func gitOut(repo string, args ...string) (string, error) {
	cmd := exec.Command("git", args...)
	cmd.Dir = repo
	b, err := cmd.Output()
	return strings.TrimSpace(string(b)), err
}
