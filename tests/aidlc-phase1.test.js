/**
 * AIDLC phase 1 tests — control and audit rails.
 * Covers: hook suite, gate-config AIDLC keys, schemas, profiles, install wiring per agent,
 * and the design invariants from docs/aidlc/design-invariants.md as executable checks.
 */
'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync, spawnSync } = require('node:child_process');

const ROOT = path.resolve(__dirname, '..');
const HOOKS = path.join(ROOT, 'hooks');
const hookDirs = fs.readdirSync(HOOKS).filter(d => d.startsWith('aidlc-'));
const jqAvailable = spawnSync('jq', ['--version']).status === 0;

describe('AIDLC hooks', () => {
  it('ships the eight designed hooks', () => {
    assert.deepStrictEqual(hookDirs.sort(), [
      'aidlc-artifact-consistency-check', 'aidlc-artifact-hygiene', 'aidlc-final-verification',
      'aidlc-human-approval-guard', 'aidlc-phase-quality-gate', 'aidlc-pre-command-guard',
      'aidlc-pre-write-guard', 'aidlc-traceability-check',
    ]);
  });

  for (const h of hookDirs) {
    describe(h, () => {
      const script = fs.readFileSync(path.join(HOOKS, h, `${h}.sh`), 'utf8');
      const manifest = fs.readFileSync(path.join(HOOKS, h, 'hook.yaml'), 'utf8');

      it('has a hook.yaml with name, event, tiers, design_ref and codes', () => {
        for (const k of ['name:', 'event:', 'tiers:', 'design_ref:', 'codes:']) {
          assert.ok(manifest.includes(k), `${h}/hook.yaml missing ${k}`);
        }
      });

      it('declares every block code it emits', () => {
        const emitted = new Set([...script.matchAll(/aidlc_block\s+"?([A-Z]\d{2})/g)].map(m => m[1]));
        for (const code of emitted) {
          assert.ok(manifest.includes(`${code}:`), `${h} emits ${code} but hook.yaml does not declare it`);
        }
      });

      it('is bash 3.2 compatible (no associative arrays, mapfile or case modifiers)', () => {
        assert.ok(!/declare\s+-A|mapfile|readarray|\$\{[A-Za-z_]+(,,|\^\^)\}/.test(script), `${h} uses bash 4+ syntax`);
      });

      it('makes no network or model calls', () => {
        const code = script.split('\n').filter(l => !/^\s*#/.test(l) && !/check\s+'/.test(l) && !/grep -E/.test(l)).join('\n');
        assert.ok(!/(^|[\s;|&(])(curl|wget|nc|ssh)\s/.test(code), `${h} invokes a network tool`);
      });
    });
  }

  it('only the approval guard writes human-decisions.md', () => {
    for (const h of hookDirs) {
      if (h === 'aidlc-human-approval-guard') continue;
      const script = fs.readFileSync(path.join(HOOKS, h, `${h}.sh`), 'utf8');
      assert.ok(!/>>?\s*"?\$?[A-Za-z_]*HDF|>>?\s*[^\n]*human-decisions\.md/.test(script), `${h} writes the decision log`);
    }
  });

  it('passes the fixture suite (one case per block code)', { skip: !jqAvailable && 'jq not installed' }, () => {
    const r = spawnSync('bash', [path.join(HOOKS, '_test', 'run.sh')], { encoding: 'utf8', timeout: 240000 });
    assert.strictEqual(r.status, 0, `hook suite failed:\n${r.stdout}\n${r.stderr}`);
    assert.match(r.stdout, /Hooks: \d+ passed, 0 failed/);
  });
});

describe('AIDLC gate config', () => {
  const gc = JSON.parse(fs.readFileSync(path.join(ROOT, 'config', 'gate-config.json'), 'utf8'));
  const RISKS = ['low', 'medium', 'high', 'security-sensitive', 'release'];

  it('maps tiers 1-3 to existing profiles', () => {
    assert.deepStrictEqual(Object.keys(gc.tier_map).sort(), ['1', '2', '3']);
    for (const p of Object.values(gc.tier_map)) assert.ok(gc.profiles[p], `tier_map names unknown profile ${p}`);
  });

  it('every HITL gate of every profile resolves to a risk level', () => {
    for (const [profile, def] of Object.entries(gc.profiles)) {
      for (const gate of def.hitl_gates) {
        const risk = (gc.risk_levels[gate] || {})[profile];
        assert.ok(RISKS.includes(risk), `${profile}/${gate} has no risk level`);
      }
    }
  });

  it('has an approval policy per risk level, casual approvals only at low', () => {
    for (const r of RISKS) assert.ok(gc.approval_policy[r], `approval_policy.${r} missing`);
    for (const r of RISKS) assert.strictEqual(gc.approval_policy[r].casual_allowed, r === 'low');
  });

  it('schemas are valid JSON with titles', () => {
    for (const f of fs.readdirSync(path.join(ROOT, 'config', 'schemas'))) {
      const s = JSON.parse(fs.readFileSync(path.join(ROOT, 'config', 'schemas', f), 'utf8'));
      assert.ok(s.title && s.type, `${f} lacks title or type`);
    }
  });

  it('profiles cover the designed work types with a tier floor', () => {
    const y = fs.readFileSync(path.join(ROOT, 'config', 'profiles.yaml'), 'utf8');
    for (const p of ['feature', 'bugfix', 'poc', 'security', 'infra', 'data', 'migration']) {
      assert.match(y, new RegExp(`\\n  ${p}:\\n    tier_floor: [123]`), `profile ${p} missing or has no tier_floor`);
    }
  });
});

describe('AIDLC install wiring', { skip: !jqAvailable && 'jq not installed' }, () => {
  function install(agent, extra = [], seed) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), `aidlc-inst-${agent}-`));
    if (seed) seed(dir);
    execFileSync('bash', [path.join(ROOT, 'setup', 'install-role.sh'), 'developer', '--agent', agent, ...extra],
      { cwd: dir, stdio: 'pipe' });
    return dir;
  }

  it('claude-code: wires hooks and keeps existing settings', () => {
    const dir = install('claude-code', [], d => {
      fs.mkdirSync(path.join(d, '.claude'));
      fs.writeFileSync(path.join(d, '.claude', 'settings.json'), JSON.stringify({
        permissions: { allow: ['Bash(ls)'] },
        hooks: { PreToolUse: [{ matcher: 'Bash', hooks: [{ type: 'command', command: 'echo mine' }] }] },
      }));
    });
    const s = JSON.parse(fs.readFileSync(path.join(dir, '.claude', 'settings.json'), 'utf8'));
    assert.deepStrictEqual(s.permissions.allow, ['Bash(ls)']);
    const cmds = JSON.stringify(s.hooks);
    for (const h of ['aidlc-pre-write-guard', 'aidlc-pre-command-guard', 'aidlc-human-approval-guard', 'aidlc-final-verification', 'aidlc-artifact-hygiene']) {
      assert.ok(cmds.includes(h), `${h} not wired`);
    }
    assert.ok(cmds.includes('echo mine'), 'user hook was dropped');
    assert.ok(fs.existsSync(path.join(dir, '.claude', 'skills', 'plan-check', 'SKILL.md')), 'plan-check not installed');
    const t = JSON.parse(fs.readFileSync(path.join(dir, '.claude', 'sdlc-central.json'), 'utf8'));
    assert.strictEqual(t.track_root, '.track');
    assert.strictEqual(t.hook_support_level, 'enforcing');
    fs.rmSync(dir, { recursive: true, force: true });
  });

  it('reinstall does not duplicate hook entries', () => {
    const dir = install('claude-code');
    execFileSync('bash', [path.join(ROOT, 'setup', 'install-role.sh'), 'developer', '--agent', 'claude-code'], { cwd: dir, stdio: 'pipe' });
    const s = JSON.parse(fs.readFileSync(path.join(dir, '.claude', 'settings.json'), 'utf8'));
    assert.strictEqual(s.hooks.UserPromptSubmit.length, 1);
    fs.rmSync(dir, { recursive: true, force: true });
  });

  it('--no-hooks installs no hooks and records the choice', () => {
    const dir = install('claude-code', ['--no-hooks', '--track-root', '.planning', '--tier-default', '1']);
    assert.ok(!fs.existsSync(path.join(dir, '.claude', 'hooks')));
    const t = JSON.parse(fs.readFileSync(path.join(dir, '.claude', 'sdlc-central.json'), 'utf8'));
    assert.strictEqual(t.hooks_installed, false);
    assert.strictEqual(t.track_root, '.planning');
    assert.strictEqual(t.tier_default, 1);
    fs.rmSync(dir, { recursive: true, force: true });
  });

  it('cursor: hooks installed as advisory scripts, nothing wired', () => {
    const dir = install('cursor');
    assert.ok(fs.existsSync(path.join(dir, '.cursor', 'hooks', 'aidlc-pre-write-guard', 'aidlc-pre-write-guard.sh')));
    assert.ok(fs.existsSync(path.join(dir, '.cursor', 'hooks', 'README.md')));
    const t = JSON.parse(fs.readFileSync(path.join(dir, '.sdlc', 'sdlc-central.json'), 'utf8'));
    assert.strictEqual(t.hook_support_level, 'advisory');
    fs.rmSync(dir, { recursive: true, force: true });
  });

  it('init-track.sh is idempotent and creates the audit rail', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'aidlc-init-'));
    execFileSync('bash', [path.join(ROOT, 'setup', 'init-track.sh')], { cwd: dir, stdio: 'pipe' });
    fs.appendFileSync(path.join(dir, '.track', 'risks.md'), '| RISK-001 | kept | me | open | |\n');
    execFileSync('bash', [path.join(ROOT, 'setup', 'init-track.sh')], { cwd: dir, stdio: 'pipe' });
    for (const f of ['state.md', 'human-decisions.md', 'lineage.md', 'requirements.md', 'decisions.md', 'risks.md', 'roadmap.md', '.gitignore']) {
      assert.ok(fs.existsSync(path.join(dir, '.track', f)), `${f} missing`);
    }
    assert.match(fs.readFileSync(path.join(dir, '.track', 'risks.md'), 'utf8'), /RISK-001 \| kept/);
    assert.match(fs.readFileSync(path.join(dir, '.track', 'state.md'), 'utf8'), /## AIDLC_RESUME\nCURRENT_PHASE: none/);
    fs.rmSync(dir, { recursive: true, force: true });
  });

  it('migrate-specs.sh copies specs into phases and --reverse restores them', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'aidlc-mig-'));
    fs.mkdirSync(path.join(dir, 'specs', '007-refunds'), { recursive: true });
    fs.writeFileSync(path.join(dir, 'specs', '007-refunds', 'spec.md'), '# Spec\nAC-1\n');
    fs.writeFileSync(path.join(dir, 'specs', '007-refunds', 'plan.md'), '# Plan\nAC-1\n');
    execFileSync('bash', [path.join(ROOT, 'setup', 'init-track.sh')], { cwd: dir, stdio: 'pipe' });
    const dry = execFileSync('bash', [path.join(ROOT, 'setup', 'migrate-specs.sh'), '--dry-run'], { cwd: dir, encoding: 'utf8' });
    assert.match(dry, /would copy specs\/007-refunds\/spec\.md -> \.track\/phases\/07-refunds\/SPEC\.md/);
    execFileSync('bash', [path.join(ROOT, 'setup', 'migrate-specs.sh')], { cwd: dir, stdio: 'pipe' });
    assert.strictEqual(fs.readFileSync(path.join(dir, '.track', 'phases', '07-refunds', 'SPEC.md'), 'utf8'), '# Spec\nAC-1\n');
    assert.match(fs.readFileSync(path.join(dir, '.track', 'lineage.md'), 'utf8'), /stage\.migrated: specs\/007-refunds\/spec\.md -> .*sha256:[0-9a-f]{64}/);
    fs.rmSync(path.join(dir, 'specs'), { recursive: true });
    execFileSync('bash', [path.join(ROOT, 'setup', 'migrate-specs.sh'), '--reverse'], { cwd: dir, stdio: 'pipe' });
    assert.strictEqual(fs.readFileSync(path.join(dir, 'specs', '007-refunds', 'plan.md'), 'utf8'), '# Plan\nAC-1\n');
    fs.rmSync(dir, { recursive: true, force: true });
  });
});
