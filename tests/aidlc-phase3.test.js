/**
 * AIDLC phase 3 tests — scorecard, release role, personas, metrics, knowledge, console, integrity, SLA.
 * Acceptance (PRD phase 3): the scorecard blocks naming the exact dimension and owner when any input
 * is missing and approves when all pass; install-role release-manager installs its skills and pipeline;
 * first-pass rate is reported from gate history.
 */
'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const { spawnSync, execFileSync } = require('node:child_process');

const ROOT = path.resolve(__dirname, '..');
const BIN = path.join(ROOT, 'hooks', '_bin');
const HOOKS = path.join(ROOT, 'hooks');
const jq = spawnSync('jq', ['--version']).status === 0;
const PH = '.track/phases/01-calc';

const run = (cwd, script, args = [], input) => spawnSync('bash', [script, ...args],
  { cwd, input, encoding: 'utf8', env: { ...process.env, AIDLC_PROJECT_DIR: cwd }, timeout: 120000 });
const bin = (cwd, name, args = []) => run(cwd, path.join(BIN, name), args);
const hook = (cwd, name, obj, args = []) => run(cwd, path.join(HOOKS, name, `${name}.sh`), args, obj ? JSON.stringify(obj) : '{}');

function setState(dir, fields) {
  const f = path.join(dir, '.track', 'state.md');
  let s = fs.readFileSync(f, 'utf8');
  for (const [k, v] of Object.entries(fields)) s = s.replace(new RegExp(`^${k}: .*$`, 'm'), `${k}: ${v}`);
  fs.writeFileSync(f, s);
}
function decide(dir, gate, risk, inputs, reply, role) {
  setState(dir, { CURRENT_PHASE: '01-calc', BLOCKED_GATE: gate, GATE_RISK: risk, NEXT_ACTION_INPUTS: inputs });
  return run(dir, path.join(HOOKS, 'aidlc-human-approval-guard', 'aidlc-human-approval-guard.sh'), ['--role', role], JSON.stringify({ prompt: reply }));
}
function project() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'aidlc-p3-'));
  execFileSync('bash', ['-c', 'git init -q && git config user.name "Dana Reviewer" && git commit -q --allow-empty -m i'], { cwd: dir });
  execFileSync('bash', [path.join(ROOT, 'setup', 'init-track.sh')], { cwd: dir, stdio: 'pipe' });
  fs.mkdirSync(path.join(dir, '.claude', 'config'), { recursive: true });
  fs.copyFileSync(path.join(ROOT, 'config', 'gate-config.json'), path.join(dir, '.claude', 'config', 'gate-config.json'));
  fs.copyFileSync(path.join(ROOT, 'config', 'profiles.yaml'), path.join(dir, '.claude', 'config', 'profiles.yaml'));
  fs.writeFileSync(path.join(dir, '.claude', 'sdlc-central.json'), '{"track_root":".track"}');
  fs.mkdirSync(path.join(dir, PH), { recursive: true });
  fs.mkdirSync(path.join(dir, 'src'));
  fs.writeFileSync(path.join(dir, PH, 'unit.yaml'), 'id: UOW-001\nname: calc\nprofile: feature\ntier: 2\nverify_command: bash test.sh\n');
  fs.appendFileSync(path.join(dir, '.track', 'requirements.md'), '| REQ-001 | sums | PO | approved |\n');
  fs.writeFileSync(path.join(dir, PH, 'SPEC.md'), '# Spec\nREQ-001\n- AC-1: add returns the sum\n');
  fs.writeFileSync(path.join(dir, PH, 'PLAN.md'), '# Plan\n- test then implement add (AC-1)\n## Rollback\nrevert\n');
  fs.writeFileSync(path.join(dir, PH, 'TASKS.md'), '## TASK-001 add\n- covers AC-1\n- Verify: `bash test.sh`\n- Files: `src/calc.sh`\n');
  fs.writeFileSync(path.join(dir, 'src', 'calc.sh'), 'add(){ echo $(($1+$2)); }\n');
  fs.writeFileSync(path.join(dir, 'test.sh'), '. src/calc.sh; [ "$(add 2 3)" = 5 ] && echo ok\n');
  return dir;
}
function completePhase(dir) {
  decide(dir, 'approve-spec', 'medium', `${PH}/SPEC.md`, 'APPROVE SPEC', 'product-owner');
  fs.writeFileSync(path.join(dir, PH, 'PLAN_CHECK.md'), '<!-- generated-by: plan-check -->\n## PLAN CHECK PASSED\n');
  decide(dir, 'approve-plan', 'medium', `${PH}/PLAN.md`, 'APPROVE PLAN', 'architect');
  setState(dir, { BLOCKED_GATE: 'none', GATE_RISK: 'none', CURRENT_STAGE: 'governance' });
  // Test first: the test fails before the change (red), then passes after it (green).
  const calc = path.join(dir, 'src', 'calc.sh'), good = fs.readFileSync(calc, 'utf8');
  fs.writeFileSync(calc, 'add(){ echo 0; }\n');
  bin(dir, 'aidlc-evidence.sh', ['run', '--task', 'TASK-001', '--red', '--', 'bash test.sh']);
  fs.writeFileSync(calc, good);
  bin(dir, 'aidlc-evidence.sh', ['run', '--task', 'TASK-001', '--suite', '--', 'bash test.sh']);
  bin(dir, 'aidlc-verify.sh');
  fs.writeFileSync(path.join(dir, PH, 'REVIEW.md'), '| Severity | Finding | Status |\n| HIGH | input validation | fixed |\n');
}
const dimRow = (out, d) => (out.split('\n').find(l => l.startsWith(`| ${d} |`)) || '');

describe('Governance scorecard', { skip: !jq && 'jq not installed' }, () => {
  it('blocks naming the exact dimension and owner when inputs are missing', () => {
    const dir = project();
    decide(dir, 'approve-spec', 'medium', `${PH}/SPEC.md`, 'APPROVE SPEC', 'product-owner');
    const r = bin(dir, 'aidlc-scorecard.sh');
    assert.strictEqual(r.status, 2);
    assert.match(dimRow(r.stdout, 'D2'), /FAIL \| missing: PLAN_CHECK\.md VERIFICATION\.md REVIEW\.md \| aidlc-delivery-manager/);
    assert.match(dimRow(r.stdout, 'D3'), /FAIL \| no accepted decision for: approve-plan \| aidlc-governance-reviewer/);
    assert.match(dimRow(r.stdout, 'D4'), /FAIL \| VERIFICATION\.md missing \| aidlc-verifier/);
    assert.match(dimRow(r.stdout, 'D6'), /FAIL \| REVIEW\.md missing/);
    assert.match(r.stdout, /## GOVERNANCE BLOCKED/);
    fs.rmSync(dir, { recursive: true, force: true });
  });

  it('approves when all six dimensions pass, seals SCORECARD.md and records gate history', () => {
    const dir = project();
    completePhase(dir);
    const r = bin(dir, 'aidlc-scorecard.sh');
    assert.strictEqual(r.status, 0, r.stdout + r.stderr);
    for (const d of ['D1', 'D2', 'D3', 'D4', 'D6']) assert.match(dimRow(r.stdout, d), /\| PASS \|/, d);
    assert.match(dimRow(r.stdout, 'D5'), /\| N\/A \|/);
    const sc = fs.readFileSync(path.join(dir, PH, 'SCORECARD.md'), 'utf8');
    const [first, ...rest] = sc.split('\n');
    const seal = first.match(/^<!-- generated-by: aidlc-scorecard sha256:([0-9a-f]{64}) -->$/)[1];
    assert.strictEqual(crypto.createHash('sha256').update(rest.join('\n')).digest('hex'), seal);
    const gh = JSON.parse(fs.readFileSync(path.join(dir, '.track', 'gate-history.json'), 'utf8'));
    assert.deepStrictEqual(gh.gates.at(-1).dimensions, { D1: 'PASS', D2: 'PASS', D3: 'PASS', D4: 'PASS', D5: 'N/A', D6: 'PASS' });
    // the release command is now allowed
    const tag = hook(dir, 'aidlc-final-verification', { tool: 'command', command: 'git tag v1' });
    assert.strictEqual(tag.status, 0, tag.stderr);
    fs.rmSync(dir, { recursive: true, force: true });
  });

  it('an open, unsigned risk blocks D6; a stale change blocks D4; an approved artifact changed blocks D3', () => {
    const dir = project();
    completePhase(dir);
    fs.appendFileSync(path.join(dir, '.track', 'risks.md'), '| RISK-009 | cache stampede | architect | open | |\n');
    let r = bin(dir, 'aidlc-scorecard.sh');
    assert.match(dimRow(r.stdout, 'D6'), /FAIL \| open risks without a signing decision: RISK-009/);
    fs.appendFileSync(path.join(dir, 'src', 'calc.sh'), '# change\n');
    bin(dir, 'aidlc-verify.sh');
    r = bin(dir, 'aidlc-scorecard.sh');
    assert.match(dimRow(r.stdout, 'D4'), /FAIL/);
    fs.appendFileSync(path.join(dir, PH, 'PLAN.md'), 'edited after approval\n');
    r = bin(dir, 'aidlc-scorecard.sh');
    assert.match(dimRow(r.stdout, 'D3'), /FAIL \| X02/);
    fs.rmSync(dir, { recursive: true, force: true });
  });

  it('SCORECARD.md cannot be hand-written or hand-edited, and release needs the sealed one', () => {
    const dir = project();
    const pre = hook(dir, 'aidlc-pre-write-guard', { tool: 'write', path: `${PH}/SCORECARD.md` });
    assert.strictEqual(pre.status, 2); assert.match(pre.stderr, /W08/);
    completePhase(dir); bin(dir, 'aidlc-scorecard.sh');
    const f = path.join(dir, PH, 'SCORECARD.md');
    fs.appendFileSync(f, 'looks fine to me\n');
    const hy = hook(dir, 'aidlc-artifact-hygiene', { tool: 'write', path: `${PH}/SCORECARD.md` });
    assert.strictEqual(hy.status, 2); assert.match(hy.stderr, /H05: .*seal mismatch/);
    const tag = hook(dir, 'aidlc-final-verification', { tool: 'command', command: 'git tag v1' });
    assert.strictEqual(tag.status, 2); assert.match(tag.stderr, /F03/);
    fs.rmSync(dir, { recursive: true, force: true });
  });
});

describe('Release manager role and pipeline', { skip: !jq && 'jq not installed' }, () => {
  it('install-role release-manager installs its skills, pipeline and template', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'aidlc-rm-'));
    execFileSync('bash', [path.join(ROOT, 'setup', 'install-role.sh'), 'release-manager', '--agent', 'claude-code'], { cwd: dir, stdio: 'pipe', env: { ...process.env, ATTICUS_EXPERIMENTAL: '1' } });
    for (const s of ['governance-scorecard', 'release-readiness-checker', 'rollback-assessor', 'aidlc-decision-guard', 'aidlc-evidence-verifier']) {
      assert.ok(fs.existsSync(path.join(dir, '.claude', 'skills', s, 'SKILL.md')), s);
    }
    assert.ok(fs.existsSync(path.join(dir, '.claude', 'pipelines', 'release-manager', 'integration-release.pipeline.yaml')));
    assert.match(fs.readFileSync(path.join(dir, 'CLAUDE.md'), 'utf8'), /Release Manager/);
    fs.rmSync(dir, { recursive: true, force: true });
  });

  it('release pipelines run the scorecard before their release gate', () => {
    for (const p of ['release-manager/integration-release', 'product-owner/release-signoff', 'qa/release-validation']) {
      const y = fs.readFileSync(path.join(ROOT, 'pipelines', `${p}.pipeline.yaml`), 'utf8');
      assert.match(y, /skill: governance-scorecard[\s\S]*pass_condition: "marker == GOVERNANCE APPROVED"/, p);
    }
  });
});

describe('Personas', () => {
  const agents = fs.readdirSync(path.join(ROOT, 'agents'));
  const skills = new Set(fs.readdirSync(path.join(ROOT, 'skills')));
  it('ships the eight designed personas', () => {
    assert.deepStrictEqual(agents.sort(), ['aidlc-delivery-manager', 'aidlc-domain-expert', 'aidlc-governance-reviewer', 'aidlc-orchestrator',
      'aidlc-plan-checker', 'aidlc-product-strategist', 'aidlc-security-standards-reviewer', 'aidlc-verifier']);
  });
  for (const a of agents) {
    it(`${a}: manifest complete, skills exist, markers in prompt, contract included`, () => {
      const y = fs.readFileSync(path.join(ROOT, 'agents', a, 'agent.yaml'), 'utf8');
      const p = fs.readFileSync(path.join(ROOT, 'agents', a, 'prompt.md'), 'utf8');
      for (const k of ['name:', 'description:', 'model_hint:', 'skills:', 'reads:', 'writes:', 'tools:', 'markers:', 'handoff_to:', 'design_ref:']) assert.ok(y.includes(k), `${a} missing ${k}`);
      for (const s of y.match(/^skills: \[(.*)\]$/m)[1].split(', ')) assert.ok(s === 'run-pipeline' || skills.has(s), `${a} references missing skill ${s}`);
      for (const m of y.match(/^markers: \[(.*)\]$/m)[1].split(', ')) assert.ok(p.includes(m.replace(/"/g, '')), `${a} prompt lacks marker ${m}`);
      assert.match(p, /## AIDLC contract/);
      assert.match(p, /Never write `human-decisions\.md`/);
    });
  }
  it('emits native files per agent', { skip: !jq && 'jq not installed' }, () => {
    const cases = { 'claude-code': ['.claude/agents/aidlc-verifier.md', /^---\nname: aidlc-verifier\ndescription: .*\ntools: Read, Grep, Glob, Bash\nmodel: sonnet\n---/],
      cursor: ['.cursor/rules/aidlc-verifier.mdc', /alwaysApply: false/], copilot: ['.github/agents/aidlc-verifier.agent.md', /^---\nname: aidlc-verifier/],
      gemini: ['.sdlc/agents/README.md', /aidlc-orchestrator/] };
    for (const [agent, [file, re]] of Object.entries(cases)) {
      const dir = fs.mkdtempSync(path.join(os.tmpdir(), `aidlc-ag-${agent}-`));
      execFileSync('bash', [path.join(ROOT, 'setup', 'install-role.sh'), 'qa', '--agent', agent], { cwd: dir, stdio: 'pipe', env: { ...process.env, ATTICUS_EXPERIMENTAL: '1' } });
      assert.match(fs.readFileSync(path.join(dir, file), 'utf8'), re, `${agent}: ${file}`);
      fs.rmSync(dir, { recursive: true, force: true });
    }
  });
});

describe('Metrics', { skip: !jq && 'jq not installed' }, () => {
  it('computes lead time, stage days, rework, approval rate and latency from artifacts; null where unmeasured', () => {
    const dir = project();
    const lin = path.join(dir, '.track', 'lineage.md');
    const ln = (ts, ev, art = `${PH}/unit.yaml`) => fs.appendFileSync(lin, `${ts} | - | ${ev} | ${art} | sha256:- | model=m1 | sdlc=t\n`);
    ln('2026-09-01T00:00:00Z', 'stage.entered: spec'); ln('2026-09-03T00:00:00Z', 'stage.entered: planning');
    ln('2026-09-04T00:00:00Z', 'decision.checkpoint_published: approve-plan');
    ln('2026-09-04T06:00:00Z', 'decision.accepted: approve-plan');
    ln('2026-09-05T00:00:00Z', 'stage.entered: execution'); ln('2026-09-09T00:00:00Z', 'stage.entered: released');
    decide(dir, 'approve-spec', 'medium', `${PH}/SPEC.md`, 'looks good', 'product-owner');
    decide(dir, 'approve-spec', 'medium', `${PH}/SPEC.md`, 'REQUEST CHANGES: add the rounding rule', 'product-owner');
    decide(dir, 'approve-spec', 'medium', `${PH}/SPEC.md`, 'APPROVE SPEC', 'product-owner');
    const r = bin(dir, 'aidlc-metrics.sh');
    assert.strictEqual(r.status, 0, r.stderr);
    const m = JSON.parse(fs.readFileSync(path.join(dir, 'docs', 'aidlc', 'metrics', 'metrics.json'), 'utf8'));
    const p = m.phases.find(x => x.phase === '01-calc');
    assert.strictEqual(p.lead_time_days, 8);
    assert.deepStrictEqual(p.stage_days, { spec: 2, planning: 2, execution: 4 });
    assert.deepStrictEqual(p.decisions, { total: 2, rework: 1, rework_rate: 0.5 });
    assert.strictEqual(m.governance.decisions_accepted, 2);
    assert.strictEqual(m.governance.vague_attempts_rejected, 1);
    assert.strictEqual(m.governance.approval_latency['approve-plan'].mean_hours, 6);
    assert.strictEqual(m.dora.releases, 1);
    assert.strictEqual(m.dora.change_failure_rate, null, 'no incidents.json means null, not zero');
    assert.ok(m.models.includes('m1'));
    assert.match(fs.readFileSync(path.join(dir, 'docs', 'aidlc', 'metrics', 'phases.csv'), 'utf8'), /^"phase","tier"/);
    fs.rmSync(dir, { recursive: true, force: true });
  });
});

describe('Measured token usage', { skip: !jq && 'jq not installed' }, () => {
  it('counts each response once, per phase, incrementally, and reports it in metrics', () => {
    const dir = project();
    const tp = path.join(dir, 'transcript.jsonl');
    const msg = (id, i, o, cr, cc) => JSON.stringify({ type: 'assistant', sessionId: 's1', message: { id, model: 'claude-x', usage: { input_tokens: i, output_tokens: o, cache_read_input_tokens: cr, cache_creation_input_tokens: cc } } });
    // one response split over two lines (same id, same usage) plus a user line
    fs.writeFileSync(tp, [msg('m1', 10, 100, 1000, 50), msg('m1', 10, 100, 1000, 50), JSON.stringify({ type: 'user' }), msg('m2', 5, 20, 500, 0)].join('\n') + '\n');
    setState(dir, { CURRENT_PHASE: '01-calc' });
    const stop = () => spawnSync('bash', [path.join(BIN, 'aidlc-usage.sh')], { input: JSON.stringify({ transcript_path: tp, session_id: 's1' }), encoding: 'utf8', env: { ...process.env, AIDLC_PROJECT_DIR: dir } });
    assert.strictEqual(stop().status, 0);
    const f = path.join(dir, '.track', 'runs', 'usage', 's1.json');
    let u = JSON.parse(fs.readFileSync(f, 'utf8'));
    assert.deepStrictEqual(u.by_phase['01-calc'], { messages: 2, input: 15, output: 120, cache_read: 1500, cache_creation: 50 });
    // a second stop with nothing new changes nothing; new lines in a new phase go to that phase
    stop();
    fs.mkdirSync(path.join(dir, '.track', 'phases', '02-next'));
    fs.writeFileSync(path.join(dir, '.track', 'phases', '02-next', 'unit.yaml'), 'id: UOW-002\nname: next\ntier: 1\n');
    setState(dir, { CURRENT_PHASE: '02-next' });
    fs.appendFileSync(tp, [msg('m2', 5, 20, 500, 0), msg('m3', 1, 30, 200, 0)].join('\n') + '\n');
    stop();
    u = JSON.parse(fs.readFileSync(f, 'utf8'));
    assert.strictEqual(u.by_phase['01-calc'].output, 120, 'no double count');
    assert.deepStrictEqual(u.by_phase['02-next'], { messages: 1, input: 1, output: 30, cache_read: 200, cache_creation: 0 }, 'm2 repeated at the boundary is skipped');
    bin(dir, 'aidlc-metrics.sh');
    const m = JSON.parse(fs.readFileSync(path.join(dir, 'docs', 'aidlc', 'metrics', 'metrics.json'), 'utf8'));
    assert.strictEqual(m.cost.tokens_total, 15 + 120 + 1500 + 50 + 1 + 30 + 200);
    assert.strictEqual(m.cost.output, 150);
    assert.strictEqual(m.phases.find(p => p.phase === '01-calc').tokens.output, 120);
    assert.deepStrictEqual(m.cost.per_tier, [{ tier: 1, units: 1, tokens_per_unit: 231 }, { tier: 2, units: 1, tokens_per_unit: 1685 }]);
    fs.rmSync(dir, { recursive: true, force: true });
  });
});

describe('Knowledge layer', { skip: !jq && 'jq not installed' }, () => {
  const page = (id, extra = {}) => {
    const fm = { id, kind: 'domain', title: 'T', owner: 'role/tech-lead', sources: '[SPEC.md]', links: '[]', review_by: '2099-01-01', ...extra };
    return `---\n${Object.entries(fm).filter(([, v]) => v !== null).map(([k, v]) => `${k}: ${v}`).join('\n')}\n---\nA cited paragraph [SPEC.md].\n`;
  };
  function wiki(pages) {
    const dir = project();
    fs.writeFileSync(path.join(dir, 'SPEC.md'), 'x');
    const w = path.join(dir, 'docs', 'aidlc', 'wiki', 'domain'); fs.mkdirSync(w, { recursive: true });
    for (const [name, text] of Object.entries(pages)) fs.writeFileSync(path.join(w, name), text);
    return dir;
  }
  const lint = (dir, args = []) => bin(dir, 'aidlc-wiki-lint.sh', args);
  it('a clean, linked wiki passes and is indexed', () => {
    const dir = wiki({ 'a.md': page('wiki/domain/a', { links: '[wiki/domain/b]' }), 'b.md': page('wiki/domain/b', { links: '[wiki/domain/a]' }) });
    assert.match(lint(dir).stdout, /L00 wiki clean \(2 page/);
    const r = bin(dir, 'aidlc-knowledge-index.sh');
    assert.match(r.stdout, /K00 index: 2 wiki page/);
    fs.rmSync(dir, { recursive: true, force: true });
  });
  const cases = {
    L01: { 'a.md': page('wiki/domain/a', { owner: null }) },
    L02: { 'a.md': page('wiki/domain/a', { kind: 'gossip' }) },
    L03: { 'a.md': page('wiki/domain/a').replace('A cited paragraph [SPEC.md].', 'An uncited claim.') },
    L04: { 'a.md': page('wiki/domain/a', { sources: '[does/not/exist.md]' }) },
    L05: { 'a.md': page('wiki/domain/a', { links: '[wiki/domain/b]' }), 'b.md': page('wiki/domain/b', { links: '[wiki/domain/a]' }), 'c.md': page('wiki/domain/c') },
    L06: { 'a.md': page('wiki/domain/a', { review_by: '2001-01-01' }) },
    L07: { 'a.md': page('wiki/domain/a', { links: '[wiki/domain/b]', 'facts:\n  grain': 'weekly' }), 'b.md': page('wiki/domain/b', { links: '[wiki/domain/a]', 'facts:\n  grain': 'daily' }) },
    L08: { 'a.md': page('wiki/domain/a', { links: '[wiki/domain/missing]' }) },
  };
  for (const [code, pages] of Object.entries(cases)) {
    it(`${code} is detected`, () => {
      const dir = wiki(pages); const r = lint(dir);
      assert.strictEqual(r.status, 2, r.stdout + r.stderr); assert.match(r.stderr, new RegExp(`^${code} `, 'm'));
      fs.rmSync(dir, { recursive: true, force: true });
    });
  }
  it('--stale-only lists overdue pages in state.md', () => {
    const dir = wiki({ 'a.md': page('wiki/domain/a', { review_by: '2001-01-01' }) });
    lint(dir, ['--stale-only']);
    assert.match(fs.readFileSync(path.join(dir, '.track', 'state.md'), 'utf8'), /## Stale knowledge\n- .*past review_by 2001-01-01/);
    fs.rmSync(dir, { recursive: true, force: true });
  });
});

describe('Console, portfolio, integrity, SLA', { skip: !jq && 'jq not installed' }, () => {
  it('portfolio data and a self-contained console are built; two repos merge', () => {
    const a = project(), b = project();
    for (const d of [a, b]) {
      fs.appendFileSync(path.join(d, '.track', 'state.md'), '| 01-calc | planning | 2 | feature | medium | none |\n');
      setState(d, { CURRENT_PHASE: '01-calc', BLOCKED_GATE: 'approve-plan', GATE_RISK: 'medium', NEXT_ACTION_INPUTS: `${PH}/PLAN.md` });
      assert.strictEqual(bin(d, 'aidlc-portfolio.sh').status, 0);
    }
    const cp = JSON.parse(fs.readFileSync(path.join(a, 'docs', 'aidlc', 'console-data', 'checkpoints.json'), 'utf8'));
    assert.strictEqual(cp.items[0].gate, 'approve-plan');
    assert.match(cp.items[0].inputs[0].sha256, /^[0-9a-f]{64}$/);
    const merged = fs.mkdtempSync(path.join(os.tmpdir(), 'aidlc-merge-'));
    bin(a, 'aidlc-portfolio.sh', ['--merge', merged, path.join(a, 'docs/aidlc/console-data'), path.join(b, 'docs/aidlc/console-data')]);
    assert.strictEqual(JSON.parse(fs.readFileSync(path.join(merged, 'portfolio.json'), 'utf8')).repos.length, 2);
    const c = bin(a, 'aidlc-console.sh');
    assert.strictEqual(c.status, 0, c.stderr);
    const html = fs.readFileSync(path.join(a, 'docs', 'aidlc', 'console', 'index.html'), 'utf8');
    const data = JSON.parse(html.match(/const DATA = (.*);\n/)[1]);
    assert.strictEqual(data.checkpoints.items[0].gate, 'approve-plan');
    assert.ok(!/<script[^>]+src=/.test(html) && !/fetch\(/.test(html), 'console must be self-contained with no network calls');
    for (const d of [a, b, merged]) fs.rmSync(d, { recursive: true, force: true });
  });

  it('integrity detects a tampered or unwired hook', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'aidlc-int-'));
    execFileSync('bash', [path.join(ROOT, 'setup', 'install-role.sh'), 'developer'], { cwd: dir, stdio: 'pipe' });
    const chk = () => spawnSync('bash', [path.join(dir, '.claude', 'hooks', '_bin', 'aidlc-integrity.sh')], { encoding: 'utf8' });
    assert.strictEqual(chk().status, 0);
    const s = path.join(dir, '.claude', 'settings.json');
    const orig = fs.readFileSync(s, 'utf8');
    fs.writeFileSync(s, orig.replace(/aidlc-human-approval-guard/g, 'nothing'));
    let r = chk(); assert.strictEqual(r.status, 2); assert.match(r.stderr, /I03/);
    fs.writeFileSync(s, orig);
    fs.appendFileSync(path.join(dir, '.claude', 'hooks', 'aidlc-pre-write-guard', 'aidlc-pre-write-guard.sh'), 'exit 0\n');
    r = chk(); assert.strictEqual(r.status, 2); assert.match(r.stderr, /I02/);
    fs.rmSync(dir, { recursive: true, force: true });
  });

  it('SLA escalates a gate waiting longer than stakeholders.yaml allows', () => {
    const dir = project();
    setState(dir, { CURRENT_PHASE: '01-calc', BLOCKED_GATE: 'approve-plan', GATE_RISK: 'medium' });
    fs.appendFileSync(path.join(dir, '.track', 'lineage.md'), `2001-01-01T00:00:00Z | - | decision.checkpoint_published: approve-plan | ${PH}/PLAN.md | sha256:- | model=m | sdlc=t\n`);
    const r = bin(dir, 'aidlc-sla.sh');
    assert.strictEqual(r.status, 2);
    assert.match(r.stdout, /S02 ESCALATE: gate approve-plan .*SLA 24h\)\. Escalate to: tech-lead/);
    fs.rmSync(dir, { recursive: true, force: true });
  });
});

describe('Registry integrity', () => {
  const cat = fs.readFileSync(path.join(ROOT, 'registry', 'catalog.yaml'), 'utf8');
  it('has each top-level key once', () => {
    for (const k of ['version', 'description', 'categories', 'skills', 'agents', 'hooks', 'roles']) {
      assert.strictEqual((cat.match(new RegExp(`^${k}:`, 'gm')) || []).length, 1, `${k} appears more than once`);
    }
  });
  it('lists every skill directory exactly once', () => {
    const block = cat.split(/^skills:\n/m)[1].split(/^agents:\n/m)[0];
    const names = [...block.matchAll(/^  - name: ([a-z0-9-]+)$/gm)].map(m => m[1]);
    assert.strictEqual(new Set(names).size, names.length, 'duplicate skill entries');
    const dirs = fs.readdirSync(path.join(ROOT, 'skills')).filter(d => fs.statSync(path.join(ROOT, 'skills', d)).isDirectory());
    assert.deepStrictEqual(names.slice().sort(), dirs.sort());
  });
  it('CI template only calls tools that ship', () => {
    const y = fs.readFileSync(path.join(ROOT, 'adapters', '_shared', 'ci', 'aidlc-checks.yml'), 'utf8');
    for (const m of y.matchAll(/hooks\/(_bin\/[a-z-]+\.sh|aidlc-[a-z-]+\/aidlc-[a-z-]+\.sh)/g)) {
      assert.ok(fs.existsSync(path.join(ROOT, 'hooks', m[1])), m[1]);
    }
  });
});
