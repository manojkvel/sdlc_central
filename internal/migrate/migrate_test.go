package migrate

import (
	"crypto/sha256"
	"encoding/hex"
	"io/fs"
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

func write(t *testing.T, p, s string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(p, []byte(s), 0o644); err != nil {
		t.Fatal(err)
	}
}

// v1Track writes a small v1 track with every record type the migration converts.
func v1Track(t *testing.T) track.Track {
	proj := t.TempDir()
	r := filepath.Join(proj, ".track")
	write(t, filepath.Join(r, "state.md"), "# Project state\n\n## AIDLC_RESUME\nCURRENT_PHASE: 01-api\nCURRENT_STAGE: planning\nBLOCKED_GATE: approve-plan\nGATE_RISK: medium\n\n## Phases\n")
	write(t, filepath.Join(r, "lineage.md"), strings.Join([]string{
		"# Lineage", "",
		"2026-09-01T09:00:00Z | - | stage.entered: intake | .track/state.md | sha256:- | model=none | sdlc=2.0.0-alpha",
		"2026-09-01T09:05:00Z | 01-api | stage.entered: spec | .track/phases/01-api/unit.yaml | sha256:- | model=x | sdlc=2.0.0-alpha",
		"2026-09-01T10:00:00Z | HD-001 | decision.accepted: approve-spec | .track/phases/01-api/SPEC.md | sha256:abc | model=x | sdlc=2.0.0-alpha",
		"2026-09-01T10:00:00Z | 01-api | stage.entered: planning | .track/phases/01-api/unit.yaml | sha256:- | model=x | sdlc=2.0.0-alpha",
		"2026-09-01T11:00:00Z | E-001 | evidence.recorded: TASK-001 test exit=0 | .track/phases/01-api/evidence/index.json | sha256:def | model=x | sdlc=2.0.0-alpha",
		"2026-09-02T08:00:00Z | 02-fix | stage.entered: execution | .track/phases/02-fix/unit.yaml | sha256:- | model=x | sdlc=2.0.0-alpha",
	}, "\n")+"\n")
	write(t, filepath.Join(r, "human-decisions.md"), strings.Join([]string{
		"# AIDLC Human Decisions Log", "", "## 2. Decision Log Index", "", "## 3. Detailed Decision Records", "",
		"### [HD-001] APPROVE SPEC",
		"- **Timestamp:** 2026-09-01T10:00:00Z",
		"- **Decider:** Dana K (product-owner), identity: asserted",
		"- **Gate:** `approve-spec` · **Risk:** medium · **Phase:** `01-api` · **Status:** APPROVED",
		"", "---", "", "## 4. Blocked Vague Approval Log",
	}, "\n")+"\n")
	write(t, filepath.Join(r, "guardrail-log.md"), "# Guardrail log\n\n| Timestamp | Hook | Code | Phase | Detail |\n| --- | --- | --- | --- | --- |\n| 2026-09-01T12:00:00Z | aidlc-pre-write-guard | W02 | 01-api | plan not checked |\n")
	write(t, filepath.Join(r, "risks.md"), "# Risk register\n\n| ID | Risk | Raised by | Status | signed_off_by |\n| --- | --- | --- | --- | --- |\n| RISK-001 | cache stampede | architect | open | |\n")
	write(t, filepath.Join(r, "gate-history.json"), `{"gates":[{"type":"release-scorecard","phase":"01-api","date":"2026-09-03T09:00:00Z","decision":"FAIL"}]}`+"\n")
	write(t, filepath.Join(r, "decisions.md"), "# Decisions\n")
	write(t, filepath.Join(r, "phases", "01-api", "unit.yaml"), "id: UOW-001\nname: api\nprofile: feature\ntier: 2\nrepos: [svc]\n")
	write(t, filepath.Join(r, "phases", "01-api", "SPEC.md"), "# Spec\n- AC-1\n")
	write(t, filepath.Join(r, "phases", "02-fix", "unit.yaml"), "id: UOW-002\nname: fix\nprofile: bugfix\ntier: 1\n")
	tr, err := track.Find(proj)
	if err != nil || tr.Layout != 1 {
		t.Fatalf("fixture is not layout 1: %v %d", err, tr.Layout)
	}
	return tr
}

func treeHash(t *testing.T, root string) map[string]string {
	t.Helper()
	out := map[string]string{}
	filepath.WalkDir(root, func(p string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		b, _ := os.ReadFile(p)
		h := sha256.Sum256(b)
		rel, _ := filepath.Rel(root, p)
		out[filepath.ToSlash(rel)] = hex.EncodeToString(h[:])
		return nil
	})
	return out
}

func sameTree(t *testing.T, want, got map[string]string) {
	t.Helper()
	for k, v := range want {
		if got[k] != v {
			t.Errorf("%s differs after round trip", k)
		}
	}
	for k := range got {
		if _, ok := want[k]; !ok {
			t.Errorf("unexpected file after round trip: %s", k)
		}
	}
}

func TestToV2ConvertsEveryRecordType(t *testing.T) {
	tr := v1Track(t)
	dry, err := ToV2(tr, true)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(tr.Root, "phases")); err != nil {
		t.Fatal("dry run changed the track")
	}
	rep, err := ToV2(tr, false)
	if err != nil {
		t.Fatal(err)
	}
	if rep.Events != dry.Events || rep.Units["01-api"] != "legacy-01-api" {
		t.Fatalf("report mismatch: dry %d real %d units %v", dry.Events, rep.Events, rep.Units)
	}
	for typ, n := range map[string]int{"stage.entered": 4, "decision.recorded": 1, "evidence.recorded": 1, "guardrail.fired": 1,
		"risk.raised": 1, "gate.evaluated": 2, "unit.started": 2, "migration.imported": 1} {
		if rep.ByType[typ] != n {
			t.Errorf("%s: %d events, want %d (%v)", typ, rep.ByType[typ], n, rep.ByType)
		}
	}
	tr2, _ := track.Find(tr.Project)
	if tr2.Layout != 2 {
		t.Fatal("layout-version not written")
	}
	for _, f := range Ledgers {
		if _, err := os.Stat(filepath.Join(tr.Root, "legacy", f)); err != nil {
			t.Errorf("%s not moved to legacy/", f)
		}
	}
	u, err := unit.Load(tr2.UnitDir("legacy-01-api"))
	if err != nil || u.ID != "legacy-01-api" || u.LegacyID != "01-api" || u.Tier != 2 || u.LegacyUOW != "UOW-001" {
		t.Fatalf("v2 unit.yaml wrong: %+v %v", u, err)
	}
	es, _ := ledger.Read(tr2.EventsDir(), "legacy-01-api")
	st := state.Fold("legacy-01-api", es)
	if st.Stage != "planning" || st.OpenGate != "approve-plan" || len(st.Decisions) != 1 || st.Decisions[0].Authenticated {
		t.Fatalf("folded state wrong: %+v", st)
	}
	if findings, _ := ledger.LintTree(tr2.EventsDir(), ".track/events"); len(findings) != 0 {
		t.Fatalf("migrated events fail lint: %v", findings)
	}
}

func TestMigrationIsIdempotent(t *testing.T) {
	a, b := v1Track(t), v1Track(t)
	if _, err := ToV2(a, false); err != nil {
		t.Fatal(err)
	}
	if _, err := ToV2(b, false); err != nil {
		t.Fatal(err)
	}
	ha, hb := treeHash(t, filepath.Join(a.Root, "events")), treeHash(t, filepath.Join(b.Root, "events"))
	if len(ha) == 0 {
		t.Fatal("no events written")
	}
	sameTree(t, ha, hb)
}

func TestRoundTripIsByteExact(t *testing.T) {
	tr := v1Track(t)
	before := treeHash(t, tr.Root)
	if _, err := ToV2(tr, false); err != nil {
		t.Fatal(err)
	}
	v2, _ := track.Find(tr.Project)
	if _, err := ToV1(v2); err != nil {
		t.Fatal(err)
	}
	sameTree(t, before, treeHash(t, tr.Root))
}

// The repository's own dogfood track must survive the round trip unchanged.
func TestRoundTripOnRepositoryTrack(t *testing.T) {
	src := filepath.Join("..", "..", ".track")
	if _, err := os.Stat(filepath.Join(src, "state.md")); err != nil {
		t.Skip("no v1 dogfood track in this checkout")
	}
	proj := t.TempDir()
	dst := filepath.Join(proj, ".track")
	filepath.WalkDir(src, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, _ := filepath.Rel(src, p)
		if d.IsDir() {
			return os.MkdirAll(filepath.Join(dst, rel), 0o755)
		}
		b, err := os.ReadFile(p)
		if err != nil {
			return err
		}
		return os.WriteFile(filepath.Join(dst, rel), b, 0o644)
	})
	before := treeHash(t, dst)
	tr, _ := track.Find(proj)
	rep, err := ToV2(tr, false)
	if err != nil {
		t.Fatal(err)
	}
	if rep.Events == 0 || len(rep.Units) == 0 {
		t.Fatalf("nothing migrated: %s", rep)
	}
	v2, _ := track.Find(proj)
	if findings, _ := ledger.LintTree(v2.EventsDir(), ".track/events"); len(findings) != 0 {
		t.Fatalf("dogfood events fail lint: %v", findings[0])
	}
	if _, err := ToV1(v2); err != nil {
		t.Fatal(err)
	}
	sameTree(t, before, treeHash(t, dst))
}

func TestWorkAfterMigrationSurvivesTheReverse(t *testing.T) {
	tr := v1Track(t)
	ToV2(tr, false)
	v2, _ := track.Find(tr.Project)
	unit.Save(v2.UnitDir("PAY-142"), unit.Unit{ID: "PAY-142", Name: "refund", Tier: 2})
	e := ledger.New("PAY-142", "stage.entered", ledger.Actor{Kind: "human", Login: "dana"})
	e.At = time.Date(2026, 9, 5, 9, 0, 0, 0, time.UTC)
	e.Data = map[string]any{"stage": "spec"}
	ledger.Write(v2.EventsDir(), e)
	rep, err := ToV1(v2)
	if err != nil {
		t.Fatal(err)
	}
	if rep.Units["PAY-142"] != "03-pay-142" || rep.Events != 1 {
		t.Fatalf("new work not restored: %+v", rep)
	}
	b, _ := os.ReadFile(filepath.Join(tr.Root, "lineage.md"))
	if !strings.Contains(string(b), "stage.entered: spec | - |") {
		t.Fatalf("new event not appended to lineage.md:\n%s", b)
	}
}
