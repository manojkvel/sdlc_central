package ledger

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// Finding is one ledger-lint problem.
type Finding struct {
	Code string // L101 modified or deleted event · L102 schema · L103 misplaced file
	Path string
	Msg  string
}

func (f Finding) String() string { return fmt.Sprintf("%s %s: %s", f.Code, f.Path, f.Msg) }

// LintDiff checks the changes between base and head in repo for the events directory eventsRel
// (relative to repo, forward slashes). Added event files must be valid and placed under their own
// unit; no existing event file may be modified, deleted or renamed. This is what CI runs on every PR.
func LintDiff(repo, base, head, eventsRel string) ([]Finding, error) {
	eventsRel = strings.TrimSuffix(filepath.ToSlash(eventsRel), "/") + "/"
	out, err := git(repo, "diff", "--name-status", "--no-renames", base+"..."+head, "--", eventsRel)
	if err != nil {
		return nil, err
	}
	var fs []Finding
	for _, line := range strings.Split(strings.TrimSpace(out), "\n") {
		if line == "" {
			continue
		}
		parts := strings.Split(line, "\t")
		status, path := parts[0], parts[len(parts)-1]
		switch status[0] {
		case 'A':
			b, err := git(repo, "show", head+":"+path)
			if err != nil {
				return nil, err
			}
			fs = append(fs, lintFile(path, eventsRel, []byte(b))...)
		default: // M, D, T, …
			fs = append(fs, Finding{"L101", path, "existing event files are immutable (status " + status + "); record a new event instead"})
		}
	}
	return fs, nil
}

// LintTree validates every event file under eventsDir (no git needed).
func LintTree(eventsDir, eventsRel string) ([]Finding, error) {
	var fs []Finding
	err := filepath.Walk(eventsDir, func(p string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() || !strings.HasSuffix(p, ".json") {
			return err
		}
		b, err := os.ReadFile(p)
		if err != nil {
			return err
		}
		rel, _ := filepath.Rel(eventsDir, p)
		fs = append(fs, lintFile(strings.TrimSuffix(filepath.ToSlash(eventsRel), "/")+"/"+filepath.ToSlash(rel), strings.TrimSuffix(filepath.ToSlash(eventsRel), "/")+"/", b)...)
		return nil
	})
	if os.IsNotExist(err) {
		err = nil
	}
	return fs, err
}

func lintFile(path, eventsRel string, b []byte) []Finding {
	var e Event
	dec := json.NewDecoder(bytes.NewReader(b))
	dec.DisallowUnknownFields()
	if err := dec.Decode(&e); err != nil {
		return []Finding{{"L102", path, "not a valid event: " + err.Error()}}
	}
	if err := e.Validate(); err != nil {
		return []Finding{{"L102", path, err.Error()}}
	}
	want := eventsRel + e.Unit + "/" + e.FileName()
	if path != want {
		return []Finding{{"L103", path, "event file must be at " + want}}
	}
	return nil
}

func git(repo string, args ...string) (string, error) {
	cmd := exec.Command("git", args...)
	cmd.Dir = repo
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	out, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("git %s: %v: %s", strings.Join(args, " "), err, strings.TrimSpace(stderr.String()))
	}
	return string(out), nil
}
