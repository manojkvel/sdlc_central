// Package ledger is the v2 audit ledger: one immutable JSON file per event,
//
//	<track>/events/<unit>/<ULID>.<type>.json     (unit-scoped)
//	<track>/events/_project/<ULID>.<type>.json   (project-scoped)
//
// It replaces the shared, append-only v1 files (lineage.md, human-decisions.md, guardrail-log.md,
// risks.md, gate-history.json). Two branches adding events never touch the same file, so merges
// never conflict. Nothing is ever edited or deleted; Lint enforces that on every pull request.
package ledger

import (
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/manojkvel/sdlc_central/internal/ids"
)

// Schema version of Event.
const Version = 1

// Project is the pseudo-unit for events that belong to no unit.
const Project = "_project"

// Types is the closed set of event types.
var Types = map[string]bool{
	"unit.started": true, "stage.entered": true, "artifact.accepted": true, "evidence.recorded": true,
	"gate.evaluated": true, "decision.recorded": true, "guardrail.fired": true, "guardrail.disputed": true,
	"risk.raised": true, "risk.closed": true, "sample.selected": true, "sample.reviewed": true,
	"deploy.recorded": true, "migration.imported": true, "cli.invoked": true,
}

// Actor is who caused the event. Authenticated is true only when the git host or CI vouched for the identity.
type Actor struct {
	ID            string `json:"id,omitempty"`    // e.g. github:1234567, entra:<oid>
	Login         string `json:"login,omitempty"` // display only
	Kind          string `json:"kind"`            // human | agent | ci
	Authenticated bool   `json:"authenticated"`
}

// Source is where the event happened.
type Source struct {
	Host   string `json:"host,omitempty"` // github | gitlab | azure | local
	Repo   string `json:"repo,omitempty"`
	Branch string `json:"branch,omitempty"`
	Commit string `json:"commit,omitempty"`
	PR     string `json:"pr,omitempty"`
	RunID  string `json:"run_id,omitempty"`
}

// Subject is the artifact the event is about.
type Subject struct {
	Path   string `json:"path,omitempty"`
	SHA256 string `json:"sha256,omitempty"`
}

// Attestation links the event to a signed predicate (filled by CI, milestone M3).
type Attestation struct {
	PredicateType string `json:"predicate_type,omitempty"`
	Ref           string `json:"ref,omitempty"`
}

// Event is one ledger record.
type Event struct {
	V           int            `json:"v"`
	ID          string         `json:"id"`
	Unit        string         `json:"unit"`
	Type        string         `json:"type"`
	At          time.Time      `json:"at"`
	Actor       Actor          `json:"actor"`
	Source      Source         `json:"source,omitempty"`
	Subject     *Subject       `json:"subject,omitempty"`
	Data        map[string]any `json:"data,omitempty"`
	Attestation *Attestation   `json:"attestation,omitempty"`
}

// Validate checks an event against the schema.
func (e Event) Validate() error {
	var errs []string
	if e.V != Version {
		errs = append(errs, fmt.Sprintf("v must be %d", Version))
	}
	if len(e.ID) != 26 {
		errs = append(errs, "id must be a 26-character ULID")
	}
	if e.Unit != Project && !ids.ValidUnit(e.Unit) {
		errs = append(errs, fmt.Sprintf("unit %q is not a valid unit id", e.Unit))
	}
	if !Types[e.Type] {
		errs = append(errs, fmt.Sprintf("type %q is not an allowed event type", e.Type))
	}
	if e.At.IsZero() {
		errs = append(errs, "at is required")
	}
	switch e.Actor.Kind {
	case "human", "agent", "ci":
	default:
		errs = append(errs, "actor.kind must be human, agent or ci")
	}
	if len(errs) > 0 {
		return errors.New(strings.Join(errs, "; "))
	}
	return nil
}

// FileName is the event's file name inside its unit directory.
func (e Event) FileName() string { return e.ID + "." + e.Type + ".json" }

// New fills the version, id and time of an event.
func New(unit, typ string, actor Actor) Event {
	now := time.Now().UTC().Truncate(time.Millisecond)
	return Event{V: Version, ID: ids.New(now), Unit: unit, Type: typ, At: now, Actor: actor}
}

// ErrExists is returned when an event file already exists: events are never overwritten.
var ErrExists = errors.New("event file already exists")

// Write stores e under eventsDir and returns the file path. It fails rather than overwrite.
func Write(eventsDir string, e Event) (string, error) {
	if err := e.Validate(); err != nil {
		return "", fmt.Errorf("invalid event: %w", err)
	}
	dir := filepath.Join(eventsDir, e.Unit)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return "", err
	}
	p := filepath.Join(dir, e.FileName())
	b, err := json.MarshalIndent(e, "", "  ")
	if err != nil {
		return "", err
	}
	f, err := os.OpenFile(p, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o644)
	if errors.Is(err, fs.ErrExist) {
		return "", fmt.Errorf("%w: %s", ErrExists, p)
	}
	if err != nil {
		return "", err
	}
	if _, err := f.Write(append(b, '\n')); err != nil {
		f.Close()
		return "", err
	}
	return p, f.Close()
}

// Read loads the events of one unit (or of all units when unit is ""), sorted by (at, id).
func Read(eventsDir, unit string) ([]Event, error) {
	var out []Event
	root := eventsDir
	if unit != "" {
		root = filepath.Join(eventsDir, unit)
	}
	err := filepath.WalkDir(root, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			if errors.Is(err, fs.ErrNotExist) {
				return filepath.SkipDir
			}
			return err
		}
		if d.IsDir() || !strings.HasSuffix(p, ".json") {
			return nil
		}
		b, err := os.ReadFile(p)
		if err != nil {
			return err
		}
		var e Event
		if err := json.Unmarshal(b, &e); err != nil {
			return fmt.Errorf("%s: %w", p, err)
		}
		out = append(out, e)
		return nil
	})
	if errors.Is(err, fs.ErrNotExist) {
		err = nil
	}
	Sort(out)
	return out, err
}

// Sort orders events by time, then id. Readers never depend on file or line order.
func Sort(es []Event) {
	sort.SliceStable(es, func(i, j int) bool {
		if !es[i].At.Equal(es[j].At) {
			return es[i].At.Before(es[j].At)
		}
		return es[i].ID < es[j].ID
	})
}
