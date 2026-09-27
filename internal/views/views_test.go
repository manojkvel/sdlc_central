package views

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/manojkvel/sdlc_central/internal/ledger"
	"github.com/manojkvel/sdlc_central/internal/state"
	"github.com/manojkvel/sdlc_central/internal/track"
	"github.com/manojkvel/sdlc_central/internal/unit"
)

func TestResumeBlockMatchesV1Keys(t *testing.T) {
	r := Resume(state.Unit{ID: "PAY-142", Stage: "planning", OpenGate: "approve-plan", GateRisk: "high", OpenRisks: map[string]string{"RISK-1": "x"}})
	for _, want := range []string{"## AIDLC_RESUME\n", "CURRENT_PHASE: PAY-142\n", "CURRENT_STAGE: planning\n", "BLOCKED_GATE: approve-plan\n", "GATE_RISK: high\n", "OPEN_RISKS: RISK-1\n", "NEXT_ACTION_OWNER: human:approve-plan\n"} {
		if !strings.Contains(r, want) {
			t.Errorf("missing %q in:\n%s", want, r)
		}
	}
	if r := Resume(state.Unit{Stage: "none"}); !strings.Contains(r, "CURRENT_PHASE: none\n") || !strings.Contains(r, "BLOCKED_GATE: none\n") {
		t.Errorf("empty unit renders wrongly:\n%s", r)
	}
}

func TestWriteViews(t *testing.T) {
	p := t.TempDir()
	os.MkdirAll(filepath.Join(p, ".track"), 0o755)
	os.WriteFile(filepath.Join(p, ".track", "layout-version"), []byte("2\n"), 0o644)
	tr, _ := track.Find(p)
	unit.Save(tr.UnitDir("PAY-142"), unit.Unit{ID: "PAY-142", Tier: 2, Profile: "feature"})
	e := ledger.New("PAY-142", "stage.entered", ledger.Actor{Kind: "agent"})
	e.At = time.Date(2026, 9, 1, 9, 0, 0, 0, time.UTC)
	e.Data = map[string]any{"stage": "execution"}
	ledger.Write(tr.EventsDir(), e)
	if err := Write(tr, "PAY-142"); err != nil {
		t.Fatal(err)
	}
	st, _ := os.ReadFile(filepath.Join(tr.ViewsDir(), "state.md"))
	if !strings.Contains(string(st), "CURRENT_STAGE: execution") || !strings.Contains(string(st), "| PAY-142 | execution | 2 | feature |") {
		t.Fatalf("state view:\n%s", st)
	}
	ln, _ := os.ReadFile(filepath.Join(tr.ViewsDir(), "lineage.md"))
	if !strings.Contains(string(ln), "2026-09-01T09:00:00Z | "+e.ID+" | stage.entered: execution") {
		t.Fatalf("lineage view:\n%s", ln)
	}
}
