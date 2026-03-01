/**
 * Pipeline Schema Tests
 * Validates all 22 pipeline YAML files for structure, references, and cycles.
 */
'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const { parseYaml } = require('./helpers/yaml-parser');

const SDLC_ROOT = path.resolve(__dirname, '..');
const PIPELINES_DIR = path.join(SDLC_ROOT, 'pipelines');
const SKILLS_DIR = path.join(SDLC_ROOT, 'skills');

const VALID_GATE_TYPES = ['quality', 'hitl', 'decision'];
const VALID_ON_FAIL = ['stop', 'hitl'];

// Collect all pipeline files
const pipelineFiles = [];
const roles = fs.readdirSync(PIPELINES_DIR).filter(d =>
  d !== '_engine' && fs.statSync(path.join(PIPELINES_DIR, d)).isDirectory()
);
for (const role of roles) {
  const roleDir = path.join(PIPELINES_DIR, role);
  const files = fs.readdirSync(roleDir).filter(f => f.endsWith('.pipeline.yaml'));
  for (const f of files) {
    pipelineFiles.push({ role, file: f, path: path.join(roleDir, f) });
  }
}

// Collect all skill names
const skillNames = new Set(
  fs.readdirSync(SKILLS_DIR).filter(d =>
    fs.statSync(path.join(SKILLS_DIR, d)).isDirectory()
  )
);

/**
 * Cycle detection using Kahn's algorithm (topological sort).
 * Returns true if there's a cycle.
 */
function hasCycle(steps) {
  const ids = new Set(steps.map(s => s.id));
  const inDegree = {};
  const adj = {};
  for (const s of steps) {
    inDegree[s.id] = 0;
    adj[s.id] = [];
  }
  for (const s of steps) {
    const deps = s.depends_on || [];
    const depList = Array.isArray(deps) ? deps : [deps];
    for (const dep of depList) {
      if (ids.has(dep)) {
        adj[dep].push(s.id);
        inDegree[s.id]++;
      }
    }
  }
  const queue = Object.keys(inDegree).filter(k => inDegree[k] === 0);
  let processed = 0;
  while (queue.length > 0) {
    const node = queue.shift();
    processed++;
    for (const next of adj[node]) {
      inDegree[next]--;
      if (inDegree[next] === 0) queue.push(next);
    }
  }
  return processed !== ids.size;
}

describe('Pipeline Schema', () => {
  it(`should have at least 22 pipeline files`, () => {
    assert.ok(pipelineFiles.length >= 22, `Expected at least 22 pipelines, found ${pipelineFiles.length}`);
  });

  for (const { role, file, path: filePath } of pipelineFiles) {
    describe(`${role}/${file}`, () => {
      let parsed;

      it('is valid YAML', () => {
        const raw = fs.readFileSync(filePath, 'utf8');
        parsed = parseYaml(raw);
        assert.ok(parsed, 'Failed to parse YAML');
      });

      it('has pipeline.name', () => {
        const raw = fs.readFileSync(filePath, 'utf8');
        parsed = parseYaml(raw);
        assert.ok(parsed.pipeline, 'Missing pipeline key');
        assert.ok(parsed.pipeline.name, 'Missing pipeline.name');
      });

      it('has steps array', () => {
        const raw = fs.readFileSync(filePath, 'utf8');
        parsed = parseYaml(raw);
        assert.ok(parsed.steps, 'Missing steps key');
        assert.ok(Array.isArray(parsed.steps), 'steps is not an array');
        assert.ok(parsed.steps.length > 0, 'steps is empty');
      });

      it('every step has id and skill', () => {
        const raw = fs.readFileSync(filePath, 'utf8');
        parsed = parseYaml(raw);
        for (const step of parsed.steps) {
          assert.ok(step.id, `Step missing id: ${JSON.stringify(step)}`);
          assert.ok(step.skill, `Step ${step.id} missing skill`);
        }
      });

      it('all skill references exist', () => {
        const raw = fs.readFileSync(filePath, 'utf8');
        parsed = parseYaml(raw);
        for (const step of parsed.steps) {
          assert.ok(
            skillNames.has(step.skill),
            `Step ${step.id} references non-existent skill "${step.skill}"`
          );
        }
      });

      it('depends_on references exist within pipeline', () => {
        const raw = fs.readFileSync(filePath, 'utf8');
        parsed = parseYaml(raw);
        const stepIds = new Set(parsed.steps.map(s => s.id));
        for (const step of parsed.steps) {
          if (step.depends_on) {
            const deps = Array.isArray(step.depends_on) ? step.depends_on : [step.depends_on];
            for (const dep of deps) {
              assert.ok(
                stepIds.has(dep),
                `Step ${step.id} depends on non-existent step "${dep}"`
              );
            }
          }
        }
      });

      it('has no dependency cycles', () => {
        const raw = fs.readFileSync(filePath, 'utf8');
        parsed = parseYaml(raw);
        assert.ok(
          !hasCycle(parsed.steps),
          `Dependency cycle detected in ${role}/${file}`
        );
      });

      it('gate types are valid', () => {
        const raw = fs.readFileSync(filePath, 'utf8');
        parsed = parseYaml(raw);
        for (const step of parsed.steps) {
          if (step.gate && step.gate.type) {
            assert.ok(
              VALID_GATE_TYPES.includes(step.gate.type),
              `Step ${step.id} has invalid gate type "${step.gate.type}"`
            );
          }
        }
      });

      it('on_fail values are valid', () => {
        const raw = fs.readFileSync(filePath, 'utf8');
        parsed = parseYaml(raw);
        for (const step of parsed.steps) {
          if (step.gate && step.gate.on_fail) {
            const onFail = step.gate.on_fail;
            if (typeof onFail === 'string') {
              assert.ok(
                VALID_ON_FAIL.includes(onFail),
                `Step ${step.id} has invalid on_fail "${onFail}"`
              );
            } else if (typeof onFail === 'object') {
              // Object form: { auto_recover: skill, fallback: hitl|stop }
              assert.ok(onFail.auto_recover, `Step ${step.id} on_fail object missing auto_recover`);
              if (onFail.fallback) {
                assert.ok(
                  VALID_ON_FAIL.includes(onFail.fallback),
                  `Step ${step.id} on_fail.fallback "${onFail.fallback}" invalid`
                );
              }
            }
          }
        }
      });
    });
  }
});
