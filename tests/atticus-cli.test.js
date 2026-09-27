/**
 * Atticus CLI tests: bin/atticus sets up the machine (shell profile, PATH, completion), installs into a
 * project with agent detection and a default role, opens units of work, and fronts the AIDLC tools.
 * The /atticus skill routes by intent to every persona and ships with every role.
 */
'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync, execFileSync } = require('node:child_process');

const ROOT = path.resolve(__dirname, '..');
const AT = path.join(ROOT, 'bin', 'atticus');
const jq = spawnSync('jq', ['--version']).status === 0;
const at = (cwd, args, env = {}) => spawnSync('bash', [AT, ...args], { cwd, encoding: 'utf8', env: { ...process.env, ...env } });
function project(markers = []) {
  const d = fs.mkdtempSync(path.join(os.tmpdir(), 'at-'));
  execFileSync('bash', ['-c', 'git init -q'], { cwd: d });
  for (const m of markers) fs.mkdirSync(path.join(d, m), { recursive: true });
  return d;
}
const guard = d => spawnSync('bash', [path.join(d, '.claude', 'hooks', 'aidlc-pre-write-guard', 'aidlc-pre-write-guard.sh')],
  { input: JSON.stringify({ tool: 'write', path: 'src/a.py' }), encoding: 'utf8', env: { ...process.env, AIDLC_PROJECT_DIR: d } });

describe('atticus CLI', { skip: !jq && 'jq not installed' }, () => {
  it('help is short, help all lists everything, unknown commands fail', () => {
    const h = at(ROOT, ['help']);
    assert.strictEqual(h.status, 0);
    assert.ok(h.stdout.split('\n').length < 25, 'short help stays short');
    assert.match(h.stdout, /\/atticus/);
    assert.match(at(ROOT, ['help', 'all']).stdout, /atticus evidence run/);
    assert.match(at(ROOT, ['version']).stdout, /^atticus \d/);
    assert.notStrictEqual(at(ROOT, ['no-such-command']).status, 0);
  });

  it('init with no arguments detects the agent, defaults the role, installs /atticus and creates the track', () => {
    const d = project(['.claude']);
    const r = at(d, ['init']);
    assert.strictEqual(r.status, 0, r.stderr);
    assert.ok(fs.existsSync(path.join(d, '.track', 'state.md')));
    assert.ok(fs.existsSync(path.join(d, '.claude', 'skills', 'atticus', 'SKILL.md')));
    assert.ok(fs.existsSync(path.join(d, '.claude', 'agents', 'aidlc-verifier.md')));
    assert.match(fs.readFileSync(path.join(d, '.claude', 'sdlc-central.json'), 'utf8'), /developer/);
    assert.match(at(d, ['status']).stdout, /^CURRENT_PHASE: none/m);
    assert.strictEqual(at(d, ['doctor']).stdout.includes('hooks intact'), true);
  });

  it('a Cursor project gets the supported AGENTS.md adapter by default', () => {
    const d = project(['.cursor']);
    const r = at(d, ['init', '--role', 'qa']);
    assert.strictEqual(r.status, 0, r.stderr);
    assert.match(r.stdout, /experimental in this release/);
    assert.ok(fs.existsSync(path.join(d, 'AGENTS.md')));
    assert.ok(!fs.existsSync(path.join(d, '.cursor', 'rules', 'sdlc-atticus.mdc')));
  });

  it('with --experimental, init picks up Cursor from the project files; add keeps it experimental', () => {
    const d = project(['.cursor']);
    assert.strictEqual(at(d, ['init', '--role', 'qa', '--experimental']).status, 0);
    assert.ok(fs.existsSync(path.join(d, '.cursor', 'rules', 'sdlc-atticus.mdc')));
    const a = at(d, ['add', 'developer']);
    assert.strictEqual(a.status, 0, a.stderr);
    assert.doesNotMatch(a.stdout, /Atticus is ready/);
    assert.ok(fs.existsSync(path.join(d, '.cursor', 'rules', 'sdlc-task-implementer.mdc')));
  });

  it('start opens tier 1 and tier 2 units that the write guard treats correctly', () => {
    const d = project(['.claude']);
    at(d, ['init']);
    assert.strictEqual(guard(d).status, 2, 'no phase: W01');
    const s1 = at(d, ['start', 'null login', '--profile', 'bugfix', '--request', 'Login crashes on empty email']);
    assert.strictEqual(s1.status, 0, s1.stderr);
    const unit = path.join(d, '.track', 'phases', '01-null-login');
    assert.match(fs.readFileSync(path.join(unit, 'unit.md'), 'utf8'), /Login crashes on empty email/);
    assert.match(at(d, ['status']).stdout, /CURRENT_STAGE: execution/);
    assert.strictEqual(guard(d).status, 0);
    assert.notStrictEqual(at(d, ['start', 'next']).status, 0, 'refuses while a phase is active');
    assert.strictEqual(at(d, ['start', 'feature-x', '--force']).status, 0);
    const g = guard(d); assert.strictEqual(g.status, 2); assert.match(g.stderr, /W02/);
    const x = spawnSync('bash', [path.join(d, '.claude', 'hooks', 'aidlc-artifact-consistency-check', 'aidlc-artifact-consistency-check.sh'), '--all'],
      { encoding: 'utf8', env: { ...process.env, AIDLC_PROJECT_DIR: d } });
    assert.match(x.stdout, /X00 consistent/, x.stderr);
  });

  it('resume names the pending decision when a gate is open', () => {
    const d = project(['.claude']);
    at(d, ['init']);
    const st = path.join(d, '.track', 'state.md');
    fs.writeFileSync(st, fs.readFileSync(st, 'utf8').replace('BLOCKED_GATE: none', 'BLOCKED_GATE: approve-plan'));
    assert.match(at(d, ['resume']).stdout, /APPROVE PLAN/);
  });

  it('setup writes one managed block per profile, is idempotent, and --undo removes it', () => {
    const H = fs.mkdtempSync(path.join(os.tmpdir(), 'at-home-'));
    fs.writeFileSync(path.join(H, '.zshrc'), 'export KEEP=1\n');
    const env = { HOME: H, SHELL: '/bin/zsh' };
    assert.strictEqual(at(H, ['setup', '-y', '--name', 'Dana K'], env).status, 0);
    at(H, ['setup', '-y'], env);
    const z = fs.readFileSync(path.join(H, '.zshrc'), 'utf8');
    assert.strictEqual((z.match(/>>> atticus >>>/g) || []).length, 1);
    assert.match(z, /export KEEP=1/);
    assert.match(z, /\$HOME\/\.local\/bin/);
    assert.ok(fs.existsSync(path.join(H, '.local', 'bin', 'atticus')));
    const b = at(H, ['setup', '-y', '--shell', 'bash'], env);
    assert.strictEqual(b.status, 0);
    assert.match(fs.readFileSync(path.join(H, '.bashrc'), 'utf8'), /completions\/atticus\.bash/);
    assert.strictEqual(at(H, ['setup', '--undo'], env).status, 0);
    assert.strictEqual(fs.readFileSync(path.join(H, '.zshrc'), 'utf8'), 'export KEEP=1\n');
    assert.ok(!fs.existsSync(path.join(H, '.local', 'bin', 'atticus')));
  });

  it('setup --global makes /atticus and the personas available to every Claude Code project', () => {
    const H = fs.mkdtempSync(path.join(os.tmpdir(), 'at-home-'));
    fs.mkdirSync(path.join(H, '.claude'));
    assert.strictEqual(at(H, ['setup', '-y', '--global'], { HOME: H, SHELL: '/bin/bash' }).status, 0);
    assert.ok(fs.existsSync(path.join(H, '.claude', 'skills', 'atticus', 'SKILL.md')));
    assert.ok(fs.existsSync(path.join(H, '.claude', 'agents', 'aidlc-orchestrator.md')));
    assert.ok(!fs.existsSync(path.join(H, '.claude', 'hooks')), 'hooks are never global');
  });
});

describe('atticus → Go core (v2 track)', { skip: spawnSync('go', ['version']).status !== 0 && 'Go not installed' }, () => {
  it('layout init, start on a branch, status, context and ledger lint go through atticus-core', () => {
    const d = fs.mkdtempSync(path.join(os.tmpdir(), 'at-v2-'));
    execFileSync('bash', ['-c', 'git init -q -b main && git config user.name Dana && git config user.email d@x'], { cwd: d });
    assert.strictEqual(at(d, ['layout', 'init']).status, 0);
    execFileSync('bash', ['-c', 'git add -A && git commit -qm init'], { cwd: d });
    const s = at(d, ['start', 'PAY-142', '--name', 'refund idempotency']);
    assert.strictEqual(s.status, 0, s.stderr);
    assert.match(s.stdout, /feat\/PAY-142-refund-idempotency/);
    assert.match(at(d, ['status']).stdout, /Unit:\s+PAY-142/);
    assert.match(at(d, ['context']).stdout, /^unit PAY-142 · stage intake/m);
    assert.match(at(d, ['ledger', 'lint']).stdout, /L000 ledger clean/);
    const m = at(d, ['migrate', '--to', 'v2']);
    assert.notStrictEqual(m.status, 0, 'a v2 track cannot be migrated to v2 again');
  });

  it('migrating a v1 track to v2 needs --force until the hooks are v2-aware, and the bash hooks warn on v2', () => {
    const d = project(['.claude']);
    at(d, ['init']);
    const r = at(d, ['migrate', '--to', 'v2']);
    assert.strictEqual(r.status, 2);
    assert.match(r.stderr, /--force/);
    assert.strictEqual(at(d, ['migrate', '--to', 'v2', '--dry-run']).status, 0);
    assert.strictEqual(at(d, ['migrate', '--to', 'v2', '--force']).status, 0);
    const w = spawnSync('bash', [path.join(d, '.claude', 'hooks', 'aidlc-pre-write-guard', 'aidlc-pre-write-guard.sh')],
      { input: JSON.stringify({ tool: 'write', path: 'src/a.py' }), encoding: 'utf8', env: { ...process.env, AIDLC_PROJECT_DIR: d } });
    assert.match(w.stderr, /layout v2.*Local enforcement is OFF/);
    assert.strictEqual(at(d, ['migrate', '--to', 'v1']).status, 0);
    assert.ok(fs.existsSync(path.join(d, '.track', 'state.md')), 'v1 restored');
  });
});

describe('/atticus skill', () => {
  const p = fs.readFileSync(path.join(ROOT, 'skills', 'atticus', 'prompt.md'), 'utf8');
  it('routes by intent to all eight personas and stays small', () => {
    for (const a of fs.readdirSync(path.join(ROOT, 'agents'))) assert.ok(p.includes(a), `${a} is routable`);
    assert.ok(p.split(/\s+/).length < 1000, 'prompt under 1,000 words');
  });
  it('ships with every role', () => {
    const src = fs.readFileSync(path.join(ROOT, 'setup', 'install-role.sh'), 'utf8');
    assert.match(src, /SKILLS=\(atticus "\$\{SKILLS\[@\]\}"\)/);
    assert.match(fs.readFileSync(path.join(ROOT, 'setup', 'install-all.sh'), 'utf8'), /^  atticus$/m);
  });
});
