package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

var bin string

func TestMain(m *testing.M) {
	dir, err := os.MkdirTemp("", "atticus-core-bin")
	if err != nil {
		panic(err)
	}
	bin = filepath.Join(dir, "atticus-core")
	if runtime.GOOS == "windows" {
		bin += ".exe"
	}
	if out, err := exec.Command("go", "build", "-o", bin, ".").CombinedOutput(); err != nil {
		panic(string(out))
	}
	code := m.Run()
	os.RemoveAll(dir)
	os.Exit(code)
}

func sh(t *testing.T, dir string, name string, args ...string) (string, error) {
	t.Helper()
	cmd := exec.Command(name, args...)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(), "GIT_AUTHOR_NAME=Dana", "GIT_AUTHOR_EMAIL=d@x", "GIT_COMMITTER_NAME=Dana", "GIT_COMMITTER_EMAIL=d@x")
	out, err := cmd.CombinedOutput()
	return strings.TrimSpace(string(out)), err
}

func must(t *testing.T, dir string, name string, args ...string) string {
	t.Helper()
	out, err := sh(t, dir, name, args...)
	if err != nil {
		t.Fatalf("%s %v: %v\n%s", name, args, err, out)
	}
	return out
}

func repo(t *testing.T) string {
	r := t.TempDir()
	must(t, r, "git", "init", "-q", "-b", "main")
	must(t, r, "git", "config", "user.name", "Dana")
	must(t, r, "git", "config", "user.email", "d@x")
	return r
}

// Two branches, in two worktrees, start units and record decisions and risks at the same time.
// Merging them in either order must never conflict, the merged ledger must lint clean, and each
// unit's folded state must be intact.
func TestParallelBranchesNeverConflict(t *testing.T) {
	for _, order := range [][2]string{{"a", "b"}, {"b", "a"}} {
		r := repo(t)
		must(t, r, bin, "layout", "init")
		must(t, r, "git", "add", "-A")
		must(t, r, "git", "commit", "-qm", "v2 track")
		base := must(t, r, "git", "rev-parse", "HEAD")

		wt := map[string]string{"a": filepath.Join(t.TempDir(), "a"), "b": filepath.Join(t.TempDir(), "b")}
		key := map[string]string{"a": "PAY-142", "b": "PAY-150"}
		for _, w := range []string{"a", "b"} {
			must(t, r, "git", "worktree", "add", "-q", "-b", "work-"+w, wt[w])
			d := wt[w]
			must(t, d, bin, "start", key[w], "--name", "work "+w)
			must(t, d, bin, "ledger", "record", "stage.entered", "stage=planning")
			must(t, d, bin, "ledger", "record", "gate.evaluated", "gate=approve-plan", "result=open", "risk=medium")
			must(t, d, bin, "ledger", "record", "decision.recorded", "gate=approve-plan", "verdict=approved")
			must(t, d, bin, "ledger", "record", "risk.raised", "--unit", "_project", "risk=RISK-"+key[w], "text=shared risk from "+w)
			must(t, d, "git", "add", "-A")
			must(t, d, "git", "commit", "-qm", "work "+w)
		}
		for _, w := range order {
			if out, err := sh(t, r, "git", "merge", "--no-ff", "-q", "-m", "merge "+w, "feat/"+key[w]+"-work-"+w); err != nil {
				t.Fatalf("order %v: merging %s conflicted: %v\n%s", order, w, err, out)
			}
		}
		if out, err := sh(t, r, bin, "ledger", "lint", "--base", base, "--head", "HEAD"); err != nil {
			t.Fatalf("merged ledger fails lint: %s", out)
		}
		for _, w := range []string{"a", "b"} {
			st := must(t, r, bin, "status", "--unit", key[w])
			if !strings.Contains(st, "Stage:       planning") || !strings.Contains(st, "Open gate:   none") || !strings.Contains(st, "Decisions:   1") {
				t.Fatalf("unit %s state after merge:\n%s", key[w], st)
			}
		}
	}
}

// The v1 layout, where both branches append to shared files, conflicts on the same scenario.
// This is the problem the v2 ledger removes.
func TestV1SharedFilesDoConflict(t *testing.T) {
	r := repo(t)
	os.MkdirAll(filepath.Join(r, ".track"), 0o755)
	os.WriteFile(filepath.Join(r, ".track", "lineage.md"), []byte("# Lineage\n"), 0o644)
	must(t, r, "git", "add", "-A")
	must(t, r, "git", "commit", "-qm", "v1")
	for _, w := range []string{"a", "b"} {
		must(t, r, "git", "switch", "-q", "-c", "v1-"+w, "main")
		f, _ := os.OpenFile(filepath.Join(r, ".track", "lineage.md"), os.O_APPEND|os.O_WRONLY, 0o644)
		f.WriteString("2026-09-01T10:00:00Z | HD-001 | decision.accepted: approve-plan | branch " + w + "\n")
		f.Close()
		must(t, r, "git", "commit", "-qam", w)
	}
	must(t, r, "git", "switch", "-q", "main")
	must(t, r, "git", "merge", "-q", "v1-a")
	if _, err := sh(t, r, "git", "merge", "-q", "v1-b"); err == nil {
		t.Fatal("expected the v1 appends to conflict")
	}
}

func TestStartBindsBranchAndRefusesDuplicates(t *testing.T) {
	r := repo(t)
	must(t, r, bin, "layout", "init")
	must(t, r, "git", "add", "-A")
	must(t, r, "git", "commit", "-qm", "init")
	out := must(t, r, bin, "start", "AB#4567", "--name", "Login fix", "--tier", "1", "--profile", "bugfix")
	if !strings.Contains(out, "ADO-4567") || !strings.Contains(out, "feat/ADO-4567-login-fix") {
		t.Fatalf("unexpected start output: %s", out)
	}
	if st := must(t, r, bin, "context"); !strings.Contains(st, "unit ADO-4567 · stage intake · tier 1") {
		t.Fatalf("context: %s", st)
	}
	if _, err := sh(t, r, bin, "start", "ADO-4567"); err == nil {
		t.Fatal("starting the same unit twice should fail")
	}
	// a local unit on a custom branch is bound through git config
	must(t, r, "git", "switch", "-q", "main")
	out = must(t, r, bin, "start", "--branch", "spike/cache", "--name", "cache spike")
	if !strings.Contains(out, "u-") {
		t.Fatalf("local unit not created: %s", out)
	}
	if st := must(t, r, bin, "status"); !strings.Contains(st, "Name:        cache spike") {
		t.Fatalf("branch binding lost: %s", st)
	}
	if _, err := sh(t, r, bin, "start", "not a key"); err == nil {
		t.Fatal("an invalid key should be refused")
	}
}

func TestLintCatchesTampering(t *testing.T) {
	r := repo(t)
	must(t, r, bin, "layout", "init")
	must(t, r, "git", "add", "-A")
	must(t, r, "git", "commit", "-qm", "init")
	must(t, r, bin, "start", "PAY-7", "--no-branch")
	must(t, r, "git", "add", "-A")
	must(t, r, "git", "commit", "-qm", "start")
	base := must(t, r, "git", "rev-parse", "HEAD")
	files, _ := filepath.Glob(filepath.Join(r, ".track", "events", "PAY-7", "*.json"))
	os.WriteFile(files[0], []byte(`{"v":1}`), 0o644)
	must(t, r, "git", "commit", "-qam", "tamper")
	out, err := sh(t, r, bin, "ledger", "lint", "--base", base, "--head", "HEAD")
	if err == nil || !strings.Contains(out, "L101") {
		t.Fatalf("tampering not caught: %v %s", err, out)
	}
}
