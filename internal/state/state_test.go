package state

import (
	"testing"
	"time"

	"github.com/manojkvel/sdlc_central/internal/ledger"
)

func ev(typ string, at int, data map[string]any) ledger.Event {
	e := ledger.New("PAY-142", typ, ledger.Actor{Kind: "human"})
	e.At = time.Date(2026, 9, 1, 0, at, 0, 0, time.UTC)
	e.Data = data
	return e
}

func TestFold(t *testing.T) {
	es := []ledger.Event{
		ev("unit.started", 0, map[string]any{"name": "refund idempotency", "tier": float64(2), "branch": "feat/PAY-142-x"}),
		ev("stage.entered", 1, map[string]any{"stage": "planning"}),
		ev("gate.evaluated", 2, map[string]any{"gate": "approve-plan", "result": "open", "risk": "high"}),
		ev("decision.recorded", 3, map[string]any{"gate": "approve-plan", "verdict": "changes_requested"}),
		ev("risk.raised", 4, map[string]any{"risk": "RISK-PAY-142-01J9", "text": "dual write window"}),
	}
	ledger.Sort(es)
	u := Fold("PAY-142", es)
	if u.Stage != "planning" || u.OpenGate != "approve-plan" || u.GateRisk != "high" || u.Tier != 2 {
		t.Fatalf("unexpected state %+v", u)
	}
	if len(u.OpenRisks) != 1 || len(u.Decisions) != 1 {
		t.Fatalf("risks %v decisions %v", u.OpenRisks, u.Decisions)
	}
	es = append(es, ev("decision.recorded", 5, map[string]any{"gate": "approve-plan", "verdict": "approved"}),
		ev("risk.closed", 6, map[string]any{"risk": "RISK-PAY-142-01J9"}))
	u = Fold("PAY-142", es)
	if u.OpenGate != "" || len(u.OpenRisks) != 0 || len(u.Decisions) != 2 {
		t.Fatalf("approval should close the gate and the risk: %+v", u)
	}
	if other := Fold("PAY-150", es); other.Stage != "none" || len(other.Decisions) != 0 {
		t.Fatal("events of another unit leaked into the fold")
	}
}

func TestUnitFromBranch(t *testing.T) {
	cases := map[string]string{
		"feat/PAY-142-refund-idempotency": "PAY-142",
		"fix/pay-9":                       "PAY-9",
		"PAY-142":                         "PAY-142",
		"feat/ADO-4567-login":             "ADO-4567",
		"chore/u-01j9x0a1b2c3d4e5f6g7h8j9k0-spike": "u-01j9x0a1b2c3d4e5f6g7h8j9k0",
		"main":                "",
		"feat/password-reset": "",
	}
	for b, want := range cases {
		if got := UnitFromBranch(b); got != want {
			t.Errorf("UnitFromBranch(%q) = %q, want %q", b, got, want)
		}
	}
}
