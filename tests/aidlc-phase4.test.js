/**
 * AIDLC phase 4 tests — hub-and-spoke contracts and the decision bot.
 * Acceptance (PRD phase 4): with two workstream repos and a hub, the consumer's implementation is
 * blocked while C-001 is DRAFT; a logged risk acceptance lets it proceed with release claims
 * excluded; approving C-001 clears the flag through LIFT EXCLUSION; a producer change that breaks
 * C-001 fails its contract test (BREACHED) and blocks the consumer again.
 * Decision bot: authenticated identity recorded, gate racing refused, stakeholder authorisation
 * (A06), authenticated identity required at high/release risk (A05, D3).
 */
'use strict';

const { describe, it, before, after } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync, execFileSync } = require('node:child_process');

const ROOT = path.resolve(__dirname, '..');
const BIN = path.join(ROOT, 'hooks', '_bin');
const HOOKS = path.join(ROOT, 'hooks');
const jq = spawnSync('jq', ['--version']).status === 0;

function repo(W, name, user = 'Alex Mercer') {
  const d = path.join(W, name); fs.mkdirSync(d);
  execFileSync('bash', ['-c', `git init -q && git config user.name "${user}" && git config user.email t@example.com && git commit -q --allow-empty -m i`], { cwd: d });
  execFileSync('bash', [path.join(ROOT, 'setup', 'init-track.sh')], { cwd: d, stdio: 'pipe' });
  fs.mkdirSync(path.join(d, '.claude', 'config'), { recursive: true });
  fs.copyFileSync(path.join(ROOT, 'config', 'gate-config.json'), path.join(d, '.claude', 'config', 'gate-config.json'));
  fs.copyFileSync(path.join(ROOT, 'config', 'profiles.yaml'), path.join(d, '.claude', 'config', 'profiles.yaml'));
  fs.writeFileSync(path.join(d, '.claude', 'sdlc-central.json'), '{"track_root":".track"}');
  return d;
}
const env = d => ({ ...process.env, AIDLC_PROJECT_DIR: d });
const K = (d, ...args) => spawnSync('bash', [path.join(BIN, 'aidlc-contract.sh'), ...args], { cwd: d, encoding: 'utf8', env: env(d) });
const guard = (d, reply, extra = ['--role', 'architect']) => spawnSync('bash', [path.join(HOOKS, 'aidlc-human-approval-guard', 'aidlc-human-approval-guard.sh'), ...extra],
  { input: JSON.stringify({ prompt: reply }), encoding: 'utf8', env: env(d) });
const write = (d, p = 'src/api.py') => spawnSync('bash', [path.join(HOOKS, 'aidlc-pre-write-guard', 'aidlc-pre-write-guard.sh')],
  { input: JSON.stringify({ tool: 'write', path: p }), encoding: 'utf8', env: env(d) });
function setState(d, fields) {
  const f = path.join(d, '.track', 'state.md'); let s = fs.readFileSync(f, 'utf8');
  for (const [k, v] of Object.entries(fields)) s = s.replace(new RegExp(`^${k}: .*$`, 'm'), `${k}: ${v}`);
  fs.writeFileSync(f, s);
}
const field = (f, k) => (fs.readFileSync(f, 'utf8').match(new RegExp(`^${k}: (.*)$`, 'm')) || [])[1];

describe('Hub-and-spoke contracts', { skip: !jq && 'jq not installed' }, () => {
  let W, hub, data, api, unit, contract;
  before(() => {
    W = fs.mkdtempSync(path.join(os.tmpdir(), 'aidlc-p4-'));
    hub = repo(W, 'hub'); data = repo(W, 'data'); api = repo(W, 'api');
    assert.match(K(hub, 'init').stdout, /K00 hub ready/);
    K(hub, 'workstream', 'WS-001', '--name', 'Data', '--repo', '../data', '--owner', 'Helen T');
    K(hub, 'workstream', 'WS-002', '--name', 'API', '--repo', '../api', '--owner', 'Robert C');
    fs.mkdirSync(path.join(data, 'schemas'));
    fs.writeFileSync(path.join(data, 'schemas', 'c001.json'), '{"grain":["product","cluster","week"]}');
    fs.writeFileSync(path.join(data, 'check.sh'), 'jq -e \'.grain == ["product","cluster","week"]\' schemas/c001.json >/dev/null\n');
    const ph = path.join(api, '.track', 'phases', '01-api'); fs.mkdirSync(ph, { recursive: true });
    unit = path.join(ph, 'unit.yaml');
    fs.writeFileSync(unit, 'id: UOW-001\nname: api\nworkstream: WS-002\ntier: 3\nhub: ../hub\nconsumes: [C-001]\n');
    fs.writeFileSync(path.join(ph, 'PLAN_CHECK.md'), '## PLAN CHECK PASSED\n');
    setState(api, { CURRENT_PHASE: '01-api', CURRENT_STAGE: 'execution' });
    contract = path.join(hub, '.track', 'contracts', 'C-001.md');
  });
  after(() => fs.rmSync(W, { recursive: true, force: true }));

  it('registers a DRAFT contract and keeps the workstream map and dependency map current', () => {
    const r = K(hub, 'register', 'C-001', '--kind', 'data', '--producer', 'WS-001', '--consumers', 'WS-002', '--schema', 'schemas/c001.json', '--test', 'bash check.sh');
    assert.match(r.stdout, /C-001 registered as DRAFT/);
    assert.strictEqual(field(contract, 'status'), 'DRAFT');
    assert.match(fs.readFileSync(path.join(hub, '.track', 'workstream-map.md'), 'utf8'), /\| WS-001 \| Data \| \.\.\/data \| Helen T \| C-001 \|/);
    assert.match(fs.readFileSync(path.join(hub, '.track', 'dependency-map.md'), 'utf8'), /WS-001 -- "C-001 DRAFT" --> WS-002/);
    assert.match(K(hub, 'register', 'C-009', '--producer', 'WS-777').stderr, /not in workstream-map/);
  });

  it('blocks the consumer (W09) while C-001 is DRAFT, and approve refuses without a decision (K01)', () => {
    const w = write(api); assert.strictEqual(w.status, 2); assert.match(w.stderr, /W09: consumed contract not approved: C-001 DRAFT/);
    assert.strictEqual(K(api, 'check').status, 2);
    const a = K(hub, 'approve', 'C-001'); assert.strictEqual(a.status, 2); assert.match(a.stderr, /K01/);
  });

  it('a plain approval needs a green contract test (K02)', () => {
    fs.writeFileSync(path.join(data, 'schemas', 'c001.json'), '{"grain":["product","week"]}');
    K(hub, 'request-approval', 'C-001');
    assert.match(guard(hub, 'APPROVE WORKSTREAM CONTRACT: WS-001 - schema and freshness reviewed').stdout, /DECISION RECEIPT HD-001/);
    const a = K(hub, 'approve', 'C-001'); assert.strictEqual(a.status, 2); assert.match(a.stderr, /K02 .*red/);
    assert.strictEqual(field(contract, 'status'), 'DRAFT');
    assert.match(field(contract, 'last_test'), /^FAIL /);
  });

  it('a risk acceptance lets the consumer build with release claims excluded', () => {
    K(hub, 'request-approval', 'C-001');
    guard(hub, 'APPROVE WORKSTREAM CONTRACT WITH RISK: WS-001 - API may build against the draft schema; exclude API release claims');
    assert.match(K(hub, 'approve', 'C-001').stdout, /APPROVED_WITH_RISK by HD-002/);
    const w = write(api); assert.strictEqual(w.status, 0, w.stderr);
    assert.strictEqual(field(unit, 'release_claims_excluded'), 'true');
    assert.strictEqual(K(api, 'check').status, 3);
    assert.match(K(api, 'propose-lift').stderr, /K03 not yet: EXCLUDED C-001/);
  });

  it('the scorecard fails D5 while claims are excluded', () => {
    const r = spawnSync('bash', [path.join(BIN, 'aidlc-scorecard.sh')], { encoding: 'utf8', env: env(api) });
    assert.match(r.stdout.split('\n').find(l => l.startsWith('| D5 |')), /FAIL \| release claims excluded: built on C-001/);
  });

  it('a green test verifies the contract, and LIFT EXCLUSION restores release claims', () => {
    fs.writeFileSync(path.join(data, 'schemas', 'c001.json'), '{"grain":["product","cluster","week"]}');
    assert.match(K(hub, 'test', 'C-001').stdout, /C-001 verified: APPROVED_WITH_RISK -> APPROVED/);
    assert.match(K(api, 'propose-lift').stdout, /Gate: lift-exclusion/);
    assert.match(guard(api, 'LIFT EXCLUSION: WS-002').stderr, /A03/, 'high risk needs an acknowledgement');
    assert.match(guard(api, 'LIFT EXCLUSION: WS-002 - C-001 verified green in the hub').stdout, /DECISION RECEIPT/);
    assert.strictEqual(field(unit, 'release_claims_excluded'), 'false');
    assert.strictEqual(K(api, 'check').status, 0);
    const r = spawnSync('bash', [path.join(BIN, 'aidlc-scorecard.sh')], { encoding: 'utf8', env: env(api) });
    assert.match(r.stdout.split('\n').find(l => l.startsWith('| D5 |')), /PASS \| consumed contracts approved: C-001/);
  });

  it('a producer change that breaks the contract marks it BREACHED and blocks the consumer until restored', () => {
    fs.writeFileSync(path.join(data, 'schemas', 'c001.json'), '{"grain":["product"]}');
    const t = K(hub, 'test', '--all'); assert.strictEqual(t.status, 2); assert.match(t.stdout, /C-001 BREACHED/);
    const w = write(api); assert.strictEqual(w.status, 2); assert.match(w.stderr, /C-001 BREACHED/);
    fs.writeFileSync(path.join(data, 'schemas', 'c001.json'), '{"grain":["product","cluster","week"]}');
    assert.match(K(hub, 'test', '--all').stdout, /restored: BREACHED -> APPROVED/);
    assert.strictEqual(write(api).status, 0);
    const lin = fs.readFileSync(path.join(hub, '.track', 'lineage.md'), 'utf8');
    for (const ev of ['contract.registered', 'contract.approved_with_risk', 'contract.verified', 'contract.breached', 'contract.restored']) assert.ok(lin.includes(ev), ev);
    for (const d of [hub, api]) {
      const cons = spawnSync('bash', [path.join(HOOKS, 'aidlc-artifact-consistency-check', 'aidlc-artifact-consistency-check.sh'), '--all'], { encoding: 'utf8', env: env(d) });
      assert.strictEqual(cons.status, 0, `${path.basename(d)}: ${cons.stderr}`);
    }
    // a real edit to an approved contract is still detected
    fs.appendFileSync(contract, 'grain also includes channel\n');
    const x = spawnSync('bash', [path.join(HOOKS, 'aidlc-artifact-consistency-check', 'aidlc-artifact-consistency-check.sh'), '--all'], { encoding: 'utf8', env: env(hub) });
    assert.strictEqual(x.status, 2); assert.match(x.stderr, /X02 approved artifact \.track\/contracts\/C-001\.md changed/);
  });
});

describe('Decision bot', { skip: !jq && 'jq not installed' }, () => {
  let W, d;
  before(() => {
    W = fs.mkdtempSync(path.join(os.tmpdir(), 'aidlc-bot-'));
    d = repo(W, 'svc');
    const ph = path.join(d, '.track', 'phases', '01-svc'); fs.mkdirSync(ph, { recursive: true });
    fs.writeFileSync(path.join(ph, 'unit.yaml'), 'id: UOW-001\nname: svc\ntier: 2\n');
    fs.writeFileSync(path.join(ph, 'PLAN.md'), '# Plan\n');
    execFileSync('bash', ['-c', 'git add -A && git commit -q -m track'], { cwd: d });
  });
  after(() => fs.rmSync(W, { recursive: true, force: true }));
  const decide = (...args) => spawnSync('bash', [path.join(BIN, 'aidlc-decide.sh'), ...args], { cwd: d, encoding: 'utf8', env: env(d) });
  const open = (gate, risk) => setState(d, { CURRENT_PHASE: '01-svc', BLOCKED_GATE: gate, GATE_RISK: risk, NEXT_ACTION_INPUTS: '.track/phases/01-svc/PLAN.md' });

  it('refuses unauthenticated identity sources, missing gates and gate races', () => {
    assert.strictEqual(decide('--decision', 'APPROVE PLAN', '--actor', 'x', '--identity', 'asserted').status, 64);
    assert.strictEqual(decide('--decision', 'APPROVE PLAN', '--actor', 'x', '--identity', 'github').status, 3);
    open('approve-plan', 'medium');
    const r = decide('--decision', 'APPROVE SPEC', '--actor', 'x', '--identity', 'github', '--expect-gate', 'approve-spec');
    assert.strictEqual(r.status, 3); assert.match(r.stderr, /open gate is approve-plan, not approve-spec/);
  });

  it('records the decision with the authenticated identity and commits it as the bot', () => {
    open('approve-plan', 'medium');
    const r = decide('--decision', 'APPROVE PLAN', '--actor', 'alex-m', '--identity', 'github', '--expect-gate', 'approve-plan', '--role', 'architect', '--commit');
    assert.strictEqual(r.status, 0, r.stderr);
    assert.match(r.stdout, /Decider: alex-m \(architect\), identity github/);
    assert.match(fs.readFileSync(path.join(d, '.track', 'human-decisions.md'), 'utf8'), /\*\*Decider:\*\* alex-m \(architect\), identity: github/);
    const log = execFileSync('git', ['log', '-1', '--format=%an|%s'], { cwd: d, encoding: 'utf8' });
    assert.match(log, /^aidlc-decision-bot\|aidlc: HD-001 approve-plan — APPROVE PLAN \(by alex-m via github\)/);
  });

  it('stakeholders.yaml people restrict who may decide a gate (A06)', () => {
    const sh = path.join(d, '.track', 'stakeholders.yaml');
    fs.writeFileSync(sh, fs.readFileSync(sh, 'utf8').replace('people: {}', 'people:\n  architect: [alex-m]\n  release-manager: [rita-k]'));
    open('approve-plan', 'medium');
    const r = decide('--decision', 'APPROVE PLAN', '--actor', 'mallory', '--identity', 'github');
    assert.strictEqual(r.status, 2); assert.match(r.stdout + r.stderr, /A06: mallory is not listed for role architect/);
    assert.strictEqual(decide('--decision', 'APPROVE PLAN', '--actor', 'alex-m', '--identity', 'github').status, 0);
  });

  it('with authenticated_identity_required, asserted decisions are rejected at release risk (A05) and bot decisions pass', () => {
    const gc = path.join(d, '.claude', 'config', 'gate-config.json');
    const g = JSON.parse(fs.readFileSync(gc, 'utf8')); g.authenticated_identity_required = true; fs.writeFileSync(gc, JSON.stringify(g));
    open('approve-release', 'release');
    const typed = guard(d, 'APPROVE RELEASE: v1.0 service only', ['--role', 'release-manager']);
    assert.strictEqual(typed.status, 2); assert.match(typed.stderr, /A05/);
    const bot = decide('--decision', 'APPROVE RELEASE: v1.0 service only', '--actor', 'rita-k', '--identity', 'github', '--expect-gate', 'approve-release');
    assert.strictEqual(bot.status, 0, bot.stdout + bot.stderr);
    open('approve-plan', 'medium');
    assert.strictEqual(guard(d, 'APPROVE PLAN').status, 0, 'medium risk still accepts a typed decision');
  });
});

describe('Phase 4 wiring', () => {
  it('install-ci --decisions installs the decision workflow, which only calls shipped tools', () => {
    const d = fs.mkdtempSync(path.join(os.tmpdir(), 'aidlc-ci-'));
    execFileSync('bash', [path.join(ROOT, 'setup', 'install-ci.sh'), '--decisions'], { cwd: d, stdio: 'pipe' });
    const y = fs.readFileSync(path.join(d, '.github', 'workflows', 'aidlc-decision.yml'), 'utf8');
    assert.match(y, /workflow_dispatch/); assert.match(y, /--actor "\$ACTOR" --identity github --push/);
    assert.ok(fs.existsSync(path.join(d, '.github', 'workflows', 'aidlc-checks.yml')));
    for (const m of y.matchAll(/hooks\/(_bin\/[a-z-]+\.sh)/g)) assert.ok(fs.existsSync(path.join(ROOT, 'hooks', m[1])), m[1]);
    fs.rmSync(d, { recursive: true, force: true });
  });
  it('contract-aware prompts are in both prompt.md and SKILL.md', () => {
    const want = { 'api-contract-analyzer': /Registry mode \(AIDLC tier 3\)/, 'plan-gen': /Built against central TDES/, 'spec-gen': /REQ-NNN/, 'design-review': /AIDLC two-tier design/, 'contract-registry': /Golden rule/ };
    for (const [s, re] of Object.entries(want)) for (const f of ['prompt.md', 'SKILL.md']) assert.match(fs.readFileSync(path.join(ROOT, 'skills', s, f), 'utf8'), re, `${s}/${f}`);
  });
  it('every role, and install-all, get the aidlc/unit-of-work pipeline; install-all includes release-manager pipelines', { skip: !jq && 'jq not installed' }, () => {
    for (const args of [['install-role.sh', 'qa'], ['install-role.sh', 'designer', '--agent', 'cursor'], ['install-all.sh']]) {
      const d = fs.mkdtempSync(path.join(os.tmpdir(), 'aidlc-uow-'));
      execFileSync('bash', [path.join(ROOT, 'setup', args[0]), ...args.slice(1)], { cwd: d, stdio: 'pipe' });
      const base = args.includes('cursor') ? '.cursor' : '.claude';
      assert.ok(fs.existsSync(path.join(d, base, 'pipelines', 'aidlc', 'unit-of-work.pipeline.yaml')), args.join(' '));
      if (args[0] === 'install-all.sh') assert.ok(fs.existsSync(path.join(d, base, 'pipelines', 'release-manager', 'integration-release.pipeline.yaml')));
      fs.rmSync(d, { recursive: true, force: true });
    }
  });

  it('the architect installs contract-first and contract-registry', { skip: !jq && 'jq not installed' }, () => {
    const d = fs.mkdtempSync(path.join(os.tmpdir(), 'aidlc-arch-'));
    execFileSync('bash', [path.join(ROOT, 'setup', 'install-role.sh'), 'architect'], { cwd: d, stdio: 'pipe' });
    assert.ok(fs.existsSync(path.join(d, '.claude', 'pipelines', 'architect', 'contract-first.pipeline.yaml')));
    assert.ok(fs.existsSync(path.join(d, '.claude', 'skills', 'contract-registry', 'SKILL.md')));
    assert.ok(fs.existsSync(path.join(d, '.claude', 'hooks', '_bin', 'aidlc-contract.sh')));
    assert.ok(fs.existsSync(path.join(d, '.claude', 'hooks', '_lib', 'contracts.sh')));
    fs.rmSync(d, { recursive: true, force: true });
  });
});
