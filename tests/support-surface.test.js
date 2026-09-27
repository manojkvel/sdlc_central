/**
 * Supported surface (roadmap M0): registry/support.yaml decides what installs by default; frozen parts
 * install only with --experimental (or ATTICUS_EXPERIMENTAL=1); CI templates are least-privilege and
 * SHA-pinned; the bench no longer rewards fast approvals.
 */
'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync, execFileSync } = require('node:child_process');

const ROOT = path.resolve(__dirname, '..');
const jq = spawnSync('jq', ['--version']).status === 0;
const list = (section, key) => execFileSync('bash', ['-c', `. adapters/_shared/support.sh; support_list . ${section} ${key}`], { cwd: ROOT, encoding: 'utf8' }).trim().split('\n');
const install = (d, args, env = {}) => spawnSync('bash', [path.join(ROOT, 'setup', 'install-role.sh'), ...args], { cwd: d, encoding: 'utf8', env: { ...process.env, ATTICUS_EXPERIMENTAL: '', ...env } });
const tmp = () => fs.mkdtempSync(path.join(os.tmpdir(), 'support-'));

describe('supported surface', () => {
  it('supported skills cover every skill the governed pipeline calls, and all exist', () => {
    const core = list('skills', 'supported');
    const used = [...fs.readFileSync(path.join(ROOT, 'pipelines', 'aidlc', 'unit-of-work.pipeline.yaml'), 'utf8').matchAll(/^\s+skill: (\S+)/gm)].map(m => m[1]);
    for (const s of used) assert.ok(core.includes(s), `pipeline skill ${s} is supported`);
    for (const s of core) assert.ok(fs.existsSync(path.join(ROOT, 'skills', s, 'skill.yaml')), s);
    for (const a of [...list('agents', 'supported'), ...list('agents', 'experimental')]) assert.ok(fs.existsSync(path.join(ROOT, 'adapters', a, 'adapter.sh')), a);
  });

  it('a default install contains the core only; experimental agents are refused with exit 3', { skip: !jq && 'jq required' }, () => {
    const d = tmp();
    const r = install(d, ['developer', '--agent', 'claude-code']);
    assert.strictEqual(r.status, 0, r.stderr);
    const skills = fs.readdirSync(path.join(d, '.claude', 'skills')).filter(s => s !== 'run-pipeline').sort();
    assert.deepStrictEqual(skills, list('skills', 'supported').sort());
    assert.ok(!fs.existsSync(path.join(d, '.claude', 'pipelines', 'developer')), 'no role pipelines by default');
    assert.ok(fs.existsSync(path.join(d, '.claude', 'pipelines', 'aidlc', 'unit-of-work.pipeline.yaml')));
    for (const t of list('tools', 'experimental')) assert.ok(!fs.existsSync(path.join(d, '.claude', 'hooks', '_bin', t)), t);
    assert.strictEqual(JSON.parse(fs.readFileSync(path.join(d, '.claude', 'sdlc-central.json'), 'utf8')).experimental, false);
    const c = install(tmp(), ['developer', '--agent', 'cursor']);
    assert.strictEqual(c.status, 3);
    assert.match(c.stderr, /--experimental/);
  });

  it('--experimental installs the frozen parts and update keeps them', { skip: !jq && 'jq required' }, () => {
    const d = tmp();
    assert.strictEqual(install(d, ['developer', '--agent', 'claude-code', '--experimental']).status, 0);
    assert.ok(fs.existsSync(path.join(d, '.claude', 'pipelines', 'developer')));
    assert.ok(fs.existsSync(path.join(d, '.claude', 'hooks', '_bin', 'aidlc-console.sh')));
    assert.strictEqual(JSON.parse(fs.readFileSync(path.join(d, '.claude', 'sdlc-central.json'), 'utf8')).experimental, true);
    const u = spawnSync('bash', [path.join(ROOT, 'setup', 'update.sh')], { cwd: d, encoding: 'utf8', env: { ...process.env, ATTICUS_EXPERIMENTAL: '' } });
    assert.strictEqual(u.status, 0, u.stderr);
    assert.ok(fs.existsSync(path.join(d, '.claude', 'hooks', '_bin', 'aidlc-console.sh')), 'still installed after update');
  });

  it('CI templates are least-privilege and pin every action by commit SHA', () => {
    for (const f of ['aidlc-checks.yml', 'aidlc-decision.yml']) {
      const y = fs.readFileSync(path.join(ROOT, 'adapters', '_shared', 'ci', f), 'utf8');
      assert.match(y, /^permissions:/m, f);
      for (const m of y.matchAll(/uses: (\S+)/g)) assert.match(m[1], /@[0-9a-f]{40}$/, `${f}: ${m[1]}`);
    }
  });

  it('the bench does not show gate wait, which would reward fast approvals', () => {
    const js = fs.readFileSync(path.join(ROOT, 'console', 'bench.js'), 'utf8');
    assert.doesNotMatch(js, /kpi\('Gate wait/);
    assert.doesNotMatch(js, /Gate wait \(h\)/);
    assert.doesNotMatch(js, /panel\('Gate wait by gate'/);
  });

  it('the hook behaviour spec covers every fixture', () => {
    const spec = fs.readFileSync(path.join(ROOT, 'docs', 'aidlc', 'spec', 'hook-behaviour.md'), 'utf8');
    const fixtures = (fs.readFileSync(path.join(ROOT, 'hooks', '_test', 'run.sh'), 'utf8').match(/^.*expect "[^"]+" aidlc-/gm) || []).length;
    const rows = (spec.match(/^\| H\d{3} \|/gm) || []).length + (spec.match(/^\| S\d{3} \|/gm) || []).length;
    assert.strictEqual(rows, fixtures + 8);
  });
});
