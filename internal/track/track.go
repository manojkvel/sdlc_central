// Package track finds a project's track root and tells the v1 layout from the v2 layout.
//
//	v1: .track/state.md with one global AIDLC_RESUME block, shared lineage.md, human-decisions.md …
//	v2: .track/layout-version = "2", units/<id>/, events/<unit>/<ULID>.<type>.json
package track

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
)

// Track is a located track root.
type Track struct {
	Project string // project directory (absolute)
	Root    string // track root (absolute)
	Layout  int    // 1 or 2; 0 when no track root exists yet
}

// AgentDirs are the directories that may hold sdlc-central.json, in lookup order.
var AgentDirs = []string{".claude", ".sdlc", ".cursor", ".github"}

// Find locates the track root for project: AIDLC_TRACK_ROOT, then track_root in sdlc-central.json, then .track.
func Find(project string) (Track, error) {
	abs, err := filepath.Abs(project)
	if err != nil {
		return Track{}, err
	}
	root := os.Getenv("AIDLC_TRACK_ROOT")
	if root == "" {
		for _, d := range AgentDirs {
			b, err := os.ReadFile(filepath.Join(abs, d, "sdlc-central.json"))
			if err != nil {
				continue
			}
			var cfg struct {
				TrackRoot string `json:"track_root"`
			}
			if json.Unmarshal(b, &cfg) == nil && cfg.TrackRoot != "" {
				root = cfg.TrackRoot
			}
			break
		}
	}
	if root == "" {
		root = ".track"
	}
	if !filepath.IsAbs(root) {
		root = filepath.Join(abs, root)
	}
	t := Track{Project: abs, Root: root}
	t.Layout = detect(root)
	return t, nil
}

func detect(root string) int {
	if b, err := os.ReadFile(filepath.Join(root, "layout-version")); err == nil && strings.TrimSpace(string(b)) == "2" {
		return 2
	}
	if _, err := os.Stat(filepath.Join(root, "state.md")); err == nil {
		return 1
	}
	return 0
}

// ErrNoTrack means the project has not adopted Atticus: hooks stay inert.
var ErrNoTrack = errors.New("no track root (run: atticus init)")

// Require returns ErrNoTrack when no track root exists.
func (t Track) Require() error {
	if t.Layout == 0 {
		return ErrNoTrack
	}
	return nil
}

// Paths in the v2 layout.
func (t Track) UnitsDir() string            { return filepath.Join(t.Root, "units") }
func (t Track) UnitDir(id string) string    { return filepath.Join(t.Root, "units", id) }
func (t Track) EventsDir() string           { return filepath.Join(t.Root, "events") }
func (t Track) UnitEvents(id string) string { return filepath.Join(t.Root, "events", id) }
func (t Track) LegacyDir() string           { return filepath.Join(t.Root, "legacy") }
func (t Track) ViewsDir() string            { return filepath.Join(t.Root, "views") }

// Rel returns p relative to the project directory, with forward slashes (stable across OSes).
func (t Track) Rel(p string) string {
	if r, err := filepath.Rel(t.Project, p); err == nil {
		return filepath.ToSlash(r)
	}
	return filepath.ToSlash(p)
}
