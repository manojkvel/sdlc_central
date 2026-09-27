// Package unit reads and writes units/<id>/unit.yaml (schema v2).
package unit

import (
	"fmt"
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

// Unit is one unit of work. In v2 its identity is the tracker issue when there is one.
type Unit struct {
	ID            string   `yaml:"id"`
	Name          string   `yaml:"name,omitempty"`
	Tracker       string   `yaml:"tracker,omitempty"`   // jira | ado | none
	IssueKey      string   `yaml:"issue_key,omitempty"` // PAY-142, ADO-4567
	Profile       string   `yaml:"profile,omitempty"`
	Tier          int      `yaml:"tier,omitempty"`
	Branch        string   `yaml:"branch,omitempty"`
	Repos         []string `yaml:"repos,omitempty,flow"`
	Request       string   `yaml:"request,omitempty"`
	VerifyCommand string   `yaml:"verify_command,omitempty"`
	LegacyID      string   `yaml:"legacy_id,omitempty"`  // v1 phase directory, e.g. 02-evidence-rail
	LegacyUOW     string   `yaml:"legacy_uow,omitempty"` // v1 id field, e.g. UOW-002
}

// Load reads dir/unit.yaml.
func Load(dir string) (Unit, error) {
	var u Unit
	b, err := os.ReadFile(filepath.Join(dir, "unit.yaml"))
	if err != nil {
		return u, err
	}
	if err := yaml.Unmarshal(b, &u); err != nil {
		return u, fmt.Errorf("%s: %w", filepath.Join(dir, "unit.yaml"), err)
	}
	return u, nil
}

// Save writes dir/unit.yaml.
func Save(dir string, u Unit) error {
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	b, err := yaml.Marshal(u)
	if err != nil {
		return err
	}
	return os.WriteFile(filepath.Join(dir, "unit.yaml"), b, 0o644)
}
