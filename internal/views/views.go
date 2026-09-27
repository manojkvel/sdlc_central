// Package views renders v1-shaped files from v2 events, for readers that have not moved yet
// (the bash hooks during the compatibility period). Views are generated, gitignored and never edited.
package views

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/manojkvel/sdlc_central/internal/ledger"
	"github.com/manojkvel/sdlc_central/internal/migrate"
	"github.com/manojkvel/sdlc_central/internal/state"
	"github.com/manojkvel/sdlc_central/internal/track"
	"github.com/manojkvel/sdlc_central/internal/unit"
)

// Resume renders the v1 AIDLC_RESUME block for one unit.
func Resume(u state.Unit) string {
	gate, risk := u.OpenGate, u.GateRisk
	if gate == "" {
		gate, risk = "none", "none"
	}
	phase := u.ID
	if phase == "" {
		phase = "none"
	}
	risks := "none"
	if len(u.OpenRisks) > 0 {
		ks := make([]string, 0, len(u.OpenRisks))
		for k := range u.OpenRisks {
			ks = append(ks, k)
		}
		sort.Strings(ks)
		risks = strings.Join(ks, ", ")
	}
	return fmt.Sprintf("## AIDLC_RESUME\nCURRENT_PHASE: %s\nCURRENT_STAGE: %s\nBLOCKED_GATE: %s\nGATE_RISK: %s\nGATE_REMINDED: no\nNEXT_ACTION: %s\nNEXT_ACTION_OWNER: %s\nNEXT_ACTION_INPUTS: none\nDONE: none\nEVIDENCE: %d run(s)\nOPEN_RISKS: %s\n",
		phase, u.Stage, gate, risk, u.NextAction(), owner(u), u.Evidence, risks)
}

func owner(u state.Unit) string {
	if u.OpenGate != "" {
		return "human:" + u.OpenGate
	}
	return "agent:aidlc-orchestrator"
}

// Write renders views/state.md (resume block for the current unit plus a table of every unit) and
// views/lineage.md (every event as a v1 lineage line). currentUnit may be "".
func Write(t track.Track, currentUnit string) error {
	events, err := ledger.Read(t.EventsDir(), "")
	if err != nil {
		return err
	}
	if err := os.MkdirAll(t.ViewsDir(), 0o755); err != nil {
		return err
	}
	var b strings.Builder
	b.WriteString("# Project state (generated view: do not edit; run atticus-core views)\n\n")
	b.WriteString(Resume(state.Fold(currentUnit, events)))
	b.WriteString("\n## Phases\n| Phase | Stage | Tier | Profile | Risk | Last decision |\n| --- | --- | --- | --- | --- | --- |\n")
	entries, _ := os.ReadDir(t.UnitsDir())
	for _, d := range entries {
		if !d.IsDir() {
			continue
		}
		u, _ := unit.Load(t.UnitDir(d.Name()))
		s := state.Fold(d.Name(), events)
		last := "-"
		if n := len(s.Decisions); n > 0 {
			last = s.Decisions[n-1].Gate + " " + s.Decisions[n-1].Verdict
		}
		risk := s.GateRisk
		if risk == "" {
			risk = "-"
		}
		fmt.Fprintf(&b, "| %s | %s | %d | %s | %s | %s |\n", d.Name(), s.Stage, u.Tier, dash(u.Profile), risk, last)
	}
	if err := os.WriteFile(filepath.Join(t.ViewsDir(), "state.md"), []byte(b.String()), 0o644); err != nil {
		return err
	}
	var l strings.Builder
	l.WriteString("# Lineage (generated view: do not edit)\n\n")
	for _, e := range events {
		l.WriteString(migrate.LineageLine(e))
		l.WriteByte('\n')
	}
	return os.WriteFile(filepath.Join(t.ViewsDir(), "lineage.md"), []byte(l.String()), 0o644)
}

func dash(s string) string {
	if s == "" {
		return "-"
	}
	return s
}
