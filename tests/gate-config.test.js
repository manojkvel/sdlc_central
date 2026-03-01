/**
 * Gate Config Tests
 * Validates config/gate-config.json structure and types.
 */
'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const CONFIG_PATH = path.resolve(__dirname, '..', 'config', 'gate-config.json');

const REQUIRED_PROFILES = ['minimal', 'standard', 'strict'];

const REQUIRED_GATES = ['spec-to-plan', 'plan-to-tasks', 'tasks-to-impl', 'impl-to-release'];

const NUMERIC_FIELDS = [
  'min_acceptance_criteria', 'min_edge_cases', 'min_phases',
  'min_task_acceptance_criteria', 'min_test_coverage_percent',
  'max_critical_findings', 'max_high_findings',
];

const BOOLEAN_FIELDS = [
  'require_security_constraints', 'require_non_goals',
  'require_risk_assessment', 'require_rollback_plan',
  'require_dependency_graph', 'require_spec_compliance',
  'require_security_audit',
];

describe('Gate Config', () => {
  let config;

  it('is valid JSON', () => {
    const raw = fs.readFileSync(CONFIG_PATH, 'utf8');
    config = JSON.parse(raw);
    assert.ok(config, 'Failed to parse gate-config.json');
  });

  it('has profiles object', () => {
    const raw = fs.readFileSync(CONFIG_PATH, 'utf8');
    config = JSON.parse(raw);
    assert.ok(config.profiles, 'Missing profiles');
    assert.strictEqual(typeof config.profiles, 'object');
  });

  for (const profile of REQUIRED_PROFILES) {
    describe(`profile: ${profile}`, () => {
      it('exists', () => {
        const raw = fs.readFileSync(CONFIG_PATH, 'utf8');
        config = JSON.parse(raw);
        assert.ok(config.profiles[profile], `Missing profile "${profile}"`);
      });

      it('has thresholds', () => {
        const raw = fs.readFileSync(CONFIG_PATH, 'utf8');
        config = JSON.parse(raw);
        assert.ok(config.profiles[profile].thresholds, `${profile} missing thresholds`);
      });

      for (const gate of REQUIRED_GATES) {
        it(`has gate "${gate}"`, () => {
          const raw = fs.readFileSync(CONFIG_PATH, 'utf8');
          config = JSON.parse(raw);
          assert.ok(
            config.profiles[profile].thresholds[gate],
            `${profile} missing gate "${gate}"`
          );
        });
      }

      it('numeric fields are numbers', () => {
        const raw = fs.readFileSync(CONFIG_PATH, 'utf8');
        config = JSON.parse(raw);
        const thresholds = config.profiles[profile].thresholds;
        for (const gate of Object.values(thresholds)) {
          for (const field of NUMERIC_FIELDS) {
            if (field in gate) {
              assert.strictEqual(
                typeof gate[field], 'number',
                `${profile}: ${field} should be number, got ${typeof gate[field]}`
              );
            }
          }
        }
      });

      it('boolean fields are booleans', () => {
        const raw = fs.readFileSync(CONFIG_PATH, 'utf8');
        config = JSON.parse(raw);
        const thresholds = config.profiles[profile].thresholds;
        for (const gate of Object.values(thresholds)) {
          for (const field of BOOLEAN_FIELDS) {
            if (field in gate) {
              assert.strictEqual(
                typeof gate[field], 'boolean',
                `${profile}: ${field} should be boolean, got ${typeof gate[field]}`
              );
            }
          }
        }
      });
    });
  }
});
