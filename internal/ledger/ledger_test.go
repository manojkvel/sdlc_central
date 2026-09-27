package ledger

import (
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func human() Actor { return Actor{Kind: "human", Login: "dana"} }

func TestWriteNeverOverwrites(t *testing.T) {
	dir := t.TempDir()
	e := New("PAY-142", "unit.started", human())
	p, err := Write(dir, e)
	if err != nil {
		t.Fatal(err)
	}
	if filepath.Base(p) != e.ID+".unit.started.json" || filepath.Base(filepath.Dir(p)) != "PAY-142" {
		t.Fatalf("unexpected path %s", p)
	}
	if _, err := Write(dir, e); !errors.Is(err, ErrExists) {
		t.Fatalf("second write should fail with ErrExists, got %v", err)
	}
}

func TestValidateRejectsBadEvents(t *testing.T) {
	bad := []Event{
		{V: 1, ID: "short", Unit: "PAY-1", Type: "unit.started", At: time.Now(), Actor: human()},
		{V: 1, ID: strings.Repeat("A", 26), Unit: "not a unit", Type: "unit.started", At: time.Now(), Actor: human()},
		{V: 1, ID: strings.Repeat("A", 26), Unit: "PAY-1", Type: "made.up", At: time.Now(), Actor: human()},
		{V: 1, ID: strings.Repeat("A", 26), Unit: "PAY-1", Type: "unit.started", Actor: human()},
		{V: 1, ID: strings.Repeat("A", 26), Unit: "PAY-1", Type: "unit.started", At: time.Now(), Actor: Actor{Kind: "robot"}},
	}
	for i, e := range bad {
		if e.Validate() == nil {
			t.Errorf("case %d should be invalid", i)
		}
	}
}

func TestReadSortsByTimeThenID(t *testing.T) {
	dir := t.TempDir()
	base := time.Date(2026, 9, 1, 12, 0, 0, 0, time.UTC)
	for _, off := range []int{3, 1, 2} {
		e := New("PAY-142", "stage.entered", human())
		e.At = base.Add(time.Duration(off) * time.Minute)
		e.Data = map[string]any{"stage": off}
		if _, err := Write(dir, e); err != nil {
			t.Fatal(err)
		}
	}
	other := New(Project, "risk.raised", human())
	other.At = base
	Write(dir, other)
	es, err := Read(dir, "PAY-142")
	if err != nil || len(es) != 3 {
		t.Fatalf("read %d events, err %v", len(es), err)
	}
	for i := 1; i < len(es); i++ {
		if es[i].At.Before(es[i-1].At) {
			t.Fatal("not sorted by time")
		}
	}
	all, _ := Read(dir, "")
	if len(all) != 4 || all[0].Unit != Project {
		t.Fatalf("all-units read: %d events, first %s", len(all), all[0].Unit)
	}
	if none, err := Read(filepath.Join(dir, "missing"), ""); err != nil || len(none) != 0 {
		t.Fatalf("missing dir should read as empty, got %d %v", len(none), err)
	}
}

func run(t *testing.T, dir string, args ...string) string {
	t.Helper()
	cmd := exec.Command(args[0], args[1:]...)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(), "GIT_AUTHOR_NAME=t", "GIT_AUTHOR_EMAIL=t@x", "GIT_COMMITTER_NAME=t", "GIT_COMMITTER_EMAIL=t@x")
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("%v: %v\n%s", args, err, out)
	}
	return strings.TrimSpace(string(out))
}

func TestLintDiff(t *testing.T) {
	repo := t.TempDir()
	run(t, repo, "git", "init", "-q", "-b", "main")
	ev := filepath.Join(repo, ".track", "events")
	first, _ := Write(ev, New("PAY-142", "unit.started", human()))
	run(t, repo, "git", "add", "-A")
	run(t, repo, "git", "commit", "-qm", "base")
	base := run(t, repo, "git", "rev-parse", "HEAD")

	// a valid new event: clean
	run(t, repo, "git", "checkout", "-qb", "ok")
	Write(ev, New("PAY-142", "stage.entered", human()))
	run(t, repo, "git", "add", "-A")
	run(t, repo, "git", "commit", "-qm", "add")
	if fs, err := LintDiff(repo, base, "HEAD", ".track/events"); err != nil || len(fs) != 0 {
		t.Fatalf("valid addition flagged: %v %v", fs, err)
	}

	// editing an existing event: L101
	run(t, repo, "git", "checkout", "-q", "-b", "edit", base)
	os.WriteFile(first, []byte(`{"tampered":true}`), 0o644)
	run(t, repo, "git", "commit", "-qam", "edit")
	fs, _ := LintDiff(repo, base, "HEAD", ".track/events")
	if len(fs) != 1 || fs[0].Code != "L101" {
		t.Fatalf("edit should be L101, got %v", fs)
	}

	// deleting an existing event: L101
	run(t, repo, "git", "checkout", "-q", "-b", "del", base)
	run(t, repo, "git", "rm", "-q", first)
	run(t, repo, "git", "commit", "-qm", "del")
	if fs, _ := LintDiff(repo, base, "HEAD", ".track/events"); len(fs) != 1 || fs[0].Code != "L101" {
		t.Fatalf("delete should be L101, got %v", fs)
	}

	// an invalid or misplaced new file: L102 / L103
	run(t, repo, "git", "checkout", "-q", "-b", "bad", base)
	os.MkdirAll(filepath.Join(ev, "PAY-9"), 0o755)
	os.WriteFile(filepath.Join(ev, "PAY-9", "junk.json"), []byte(`{"v":1}`), 0o644)
	misplaced := New("PAY-142", "stage.entered", human())
	Write(filepath.Join(ev, "wrong"), misplaced)
	run(t, repo, "git", "add", "-A")
	run(t, repo, "git", "commit", "-qm", "bad")
	fs, _ = LintDiff(repo, base, "HEAD", ".track/events")
	codes := map[string]bool{}
	for _, f := range fs {
		codes[f.Code] = true
	}
	if !codes["L102"] || !codes["L103"] {
		t.Fatalf("want L102 and L103, got %v", fs)
	}
}
