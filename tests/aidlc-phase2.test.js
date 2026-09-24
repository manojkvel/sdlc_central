/**
 * AIDLC phase 2 tests — evidence rail.
 * Acceptance (PRD phase 2): VERIFICATION.md maps every AC to evidence; deleting an evidence
 * log fails that AC; editing source after its evidence marks it stale; a hand-written or
 * hand-edited VERIFICATION.md is rejected. Plus: re-execution disagreement, tier 1 skip,
 * fail-closed coverage, recorder exit-code passthrough, and the release gate reading it all.
 */
'use strict';

const { describe, it, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync, execFileSync } = require('node:child_process');

const ROOT = path.resolve(__dirname, '..');
const BIN = path.join(ROOT, 'hooks', '_bin');
const HOOKS = path.join(ROOT, 'hooks');
const jqAvailable = spawnSync('jq', ['--version']).status === 0;
const PH = '.track/phases/01-calc';

function sh(cwd, args, env = {}) {
  return spawnSync('bash', args, { cwd, encoding: 'utf8', env: { ...process.env, AIDLC_PROJECT_DIR: cwd, ...env }, timeout: 60000 });
}
const record = (dir, task, extra, cmd) => sh(dir, [path.join(BIN, 'aidlc-evidence.sh'), 'run', '--task', task, ...extra, '--', cmd]);
const verify = (dir, extra = []) => sh(dir, [path.join(BIN, 'aidlc-verify.sh'), ...extra]);
const readV = dir => fs.readFileSync(path.join(dir, PH, 'VERIFICATION.md'), 'utf8');
const row = (v, id) => (v.split('\n').find(l => l.startsWith(`| ${id} |`)) || '');

function project({ tier = 2 } = {}) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'aidlc-ev-'));
  execFileSync('bash', ['-c', 'git init -q && git config user.name T && git commit -q --allow-empty -m init'], { cwd: dir });
  execFileSync('bash', [path.join(ROOT, 'setup', 'init-track.sh')], { cwd: dir, stdio: 'pipe' });
  fs.mkdirSync(path.join(dir, PH), { recursive: true });
  fs.mkdirSync(path.join(dir, 'src'));
  fs.writeFileSync(path.join(dir, PH, 'unit.yaml'), `id: UOW-001\nname: calc\ntier: ${tier}\nverify_command: bash test.sh\n`);
  fs.writeFileSync(path.join(dir, PH, 'SPEC.md'), '# Spec\n- AC-1: add returns the sum\n- AC-2: add is defined in src\n');
  fs.writeFileSync(path.join(dir, PH, 'TASKS.md'), '## TASK-001 add\n- covers AC-1\n## TASK-002 definition\n- covers AC-2\n');
  fs.writeFileSync(path.join(dir, 'src', 'calc.sh'), 'add(){ echo $(($1+$2)); }\n');
  fs.writeFileSync(path.join(dir, 'test.sh'), '. src/calc.sh; [ "$(add 2 3)" = 5 ] && echo test_add ok\n');
  const state = path.join(dir, '.track', 'state.md');
  fs.writeFileSync(state, fs.readFileSync(state, 'utf8')
    .replace('CURRENT_PHASE: none', 'CURRENT_PHASE: 01-calc').replace('CURRENT_STAGE: intake', 'CURRENT_STAGE: execution'));
  return dir;
}
const recordBoth = dir => {
  record(dir, 'TASK-001', ['--suite'], 'bash test.sh');
  record(dir, 'TASK-002', ['--ac', 'AC-2'], 'grep -q add src/calc.sh && echo defined');
};

describe('AIDLC evidence rail', { skip: !jqAvailable && 'jq not installed' }, () => {
  let dir;
  beforeEach(() => { dir = project(); });
  afterEach(() => fs.rmSync(dir, { recursive: true, force: true }));

  it('recorder captures output, exit code, touched-file hashes and passes the exit code through', () => {
    const ok = record(dir, 'TASK-001', ['--suite'], 'bash test.sh');
    assert.strictEqual(ok.status, 0);
    assert.match(ok.stdout, /AIDLC EVIDENCE E-001 recorded for TASK-001: exit 0/);
    const bad = record(dir, 'TASK-001', [], 'exit 3');
    assert.strictEqual(bad.status, 3, 'recorder must pass the command exit code through');
    const idx = JSON.parse(fs.readFileSync(path.join(dir, PH, 'evidence', 'index.json'), 'utf8'));
    assert.strictEqual(idx.entries.length, 2);
    const e = idx.entries[0];
    assert.strictEqual(e.exit_code, 0);
    assert.strictEqual(e.suite, true);
    assert.match(e.stdout_sha256, /^[0-9a-f]{64}$/);
    assert.ok(e.touched_files.some(f => f.path === 'src/calc.sh' && /^[0-9a-f]{64}$/.test(f.sha256)));
    assert.strictEqual(fs.readFileSync(path.join(dir, PH, e.stdout_path), 'utf8'), 'test_add ok\n');
    assert.match(fs.readFileSync(path.join(dir, '.track', 'lineage.md'), 'utf8'), /\| E-001 \| evidence\.recorded: TASK-001 test exit=0/);
  });

  it('maps every AC to evidence and completes when all are fresh and passing', () => {
    recordBoth(dir);
    const r = verify(dir);
    assert.strictEqual(r.status, 0, r.stdout + r.stderr);
    const v = readV(dir);
    assert.match(row(v, 'AC-1'), /\| PASS \| E-001 \(TASK-001, exit 0\)/);
    assert.match(row(v, 'AC-2'), /\| PASS \| E-002/);
    assert.match(row(v, 'RERUN'), /\| PASS \|/);
    assert.match(v, /## VERIFICATION COMPLETE\n$/);
  });

  it('fails closed: a criterion with no evidence fails', () => {
    record(dir, 'TASK-001', ['--suite'], 'bash test.sh');
    const r = verify(dir);
    assert.strictEqual(r.status, 2);
    assert.match(row(readV(dir), 'AC-2'), /\| FAIL \| — \| no evidence covers this criterion/);
  });

  it('deleting an evidence log fails the criterion it covered', () => {
    recordBoth(dir);
    const idx = JSON.parse(fs.readFileSync(path.join(dir, PH, 'evidence', 'index.json'), 'utf8'));
    fs.rmSync(path.join(dir, PH, idx.entries[0].stdout_path));
    assert.strictEqual(verify(dir).status, 2);
    assert.match(row(readV(dir), 'AC-1'), /FAIL .*E-001 log missing/);
  });

  it('editing a log after recording fails as altered', () => {
    recordBoth(dir);
    const idx = JSON.parse(fs.readFileSync(path.join(dir, PH, 'evidence', 'index.json'), 'utf8'));
    fs.appendFileSync(path.join(dir, PH, idx.entries[1].stdout_path), 'extra\n');
    assert.strictEqual(verify(dir).status, 2);
    assert.match(row(readV(dir), 'AC-2'), /E-002 log altered/);
  });

  it('editing source after its evidence makes that evidence stale, and the index says so', () => {
    recordBoth(dir);
    fs.appendFileSync(path.join(dir, 'src', 'calc.sh'), '# later change\n');
    assert.strictEqual(verify(dir).status, 2);
    assert.match(row(readV(dir), 'AC-1'), /stale: src\/calc\.sh changed/);
    const idx = JSON.parse(fs.readFileSync(path.join(dir, PH, 'evidence', 'index.json'), 'utf8'));
    assert.ok(idx.entries.every(e => e.stale === true));
    recordBoth(dir);
    assert.strictEqual(verify(dir).status, 0, 're-recording after the change should verify again');
  });

  it('re-execution that disagrees with recorded evidence fails', () => {
    recordBoth(dir);
    fs.writeFileSync(path.join(dir, 'test.sh'), 'exit 1\n');
    // test.sh was a touched file, so AC-1 is also stale; the RERUN row must fail on its own
    assert.strictEqual(verify(dir).status, 2);
    assert.match(row(readV(dir), 'RERUN'), /\| FAIL \| .*fresh run exited 1/);
  });

  it('no suite command is a FAIL unless a human waiver is given', () => {
    fs.writeFileSync(path.join(dir, PH, 'unit.yaml'), 'id: UOW-001\nname: calc\ntier: 2\n');
    record(dir, 'TASK-001', [], 'bash test.sh');
    record(dir, 'TASK-002', ['--ac', 'AC-2'], 'grep -q add src/calc.sh');
    assert.strictEqual(verify(dir).status, 2);
    assert.match(row(readV(dir), 'RERUN'), /no suite command/);
    assert.strictEqual(verify(dir, ['--no-rerun', 'HD-004 waived: suite needs prod data']).status, 0);
    assert.match(row(readV(dir), 'RERUN'), /\| WAIVED \| .*HD-004 waived/);
  });

  it('generated file is sealed; hygiene accepts it and rejects a hand edit', () => {
    recordBoth(dir);
    verify(dir);
    const run = () => spawnSync('bash', [path.join(HOOKS, 'aidlc-artifact-hygiene', 'aidlc-artifact-hygiene.sh')],
      { input: JSON.stringify({ tool: 'write', path: `${PH}/VERIFICATION.md` }), encoding: 'utf8', env: { ...process.env, AIDLC_PROJECT_DIR: dir } });
    assert.strictEqual(run().status, 0);
    const f = path.join(dir, PH, 'VERIFICATION.md');
    fs.writeFileSync(f, fs.readFileSync(f, 'utf8').replace('| FAIL |', '| PASS |').replace('AC-1 | add', 'AC-1 | ADD'));
    const r = run();
    assert.strictEqual(r.status, 2);
    assert.match(r.stderr, /H05: .*seal mismatch/);
  });

  it('a hand-written VERIFICATION.md is rejected by the pre-write guard and by hygiene', () => {
    const pre = spawnSync('bash', [path.join(HOOKS, 'aidlc-pre-write-guard', 'aidlc-pre-write-guard.sh')],
      { input: JSON.stringify({ tool: 'write', path: `${PH}/VERIFICATION.md` }), encoding: 'utf8', env: { ...process.env, AIDLC_PROJECT_DIR: dir } });
    assert.strictEqual(pre.status, 2);
    assert.match(pre.stderr, /W08/);
    fs.writeFileSync(path.join(dir, PH, 'VERIFICATION.md'), '| AC-1 | PASS |\n## VERIFICATION COMPLETE\n');
    const hyg = spawnSync('bash', [path.join(HOOKS, 'aidlc-artifact-hygiene', 'aidlc-artifact-hygiene.sh')],
      { input: JSON.stringify({ tool: 'write', path: `${PH}/VERIFICATION.md` }), encoding: 'utf8', env: { ...process.env, AIDLC_PROJECT_DIR: dir } });
    assert.strictEqual(hyg.status, 2);
    assert.match(hyg.stderr, /H05/);
  });

  it('release is blocked while verification failed, and allowed once it is complete with a scorecard', () => {
    record(dir, 'TASK-001', ['--suite'], 'bash test.sh');
    verify(dir);
    fs.writeFileSync(path.join(dir, PH, 'REVIEW.md'), '| HIGH | x | fixed |\n');
    fs.writeFileSync(path.join(dir, PH, 'SCORECARD.md'), '## GOVERNANCE APPROVED\n');
    const tag = () => spawnSync('bash', [path.join(HOOKS, 'aidlc-final-verification', 'aidlc-final-verification.sh')],
      { input: JSON.stringify({ tool: 'command', command: 'git tag v1.0.0' }), encoding: 'utf8', env: { ...process.env, AIDLC_PROJECT_DIR: dir } });
    let r = tag();
    assert.strictEqual(r.status, 2);
    assert.match(r.stderr, /F01/);
    record(dir, 'TASK-002', ['--ac', 'AC-2'], 'grep -q add src/calc.sh');
    assert.strictEqual(verify(dir).status, 0);
    r = tag();
    assert.strictEqual(r.status, 0, r.stderr);
  });

  it('UAT mode reads only uat evidence and writes UAT.md', () => {
    recordBoth(dir);
    assert.strictEqual(verify(dir, ['--mode', 'uat']).status, 2, 'test evidence must not count as UAT');
    record(dir, 'UAT-01', ['--kind', 'uat', '--ac', 'AC-1,AC-2'], 'bash test.sh');
    assert.strictEqual(verify(dir, ['--mode', 'uat']).status, 0);
    assert.match(fs.readFileSync(path.join(dir, PH, 'UAT.md'), 'utf8'), /^<!-- generated-by: aidlc-evidence-verifier sha256:[0-9a-f]{64} -->/);
  });
});

describe('AIDLC evidence rail — tier 1', { skip: !jqAvailable && 'jq not installed' }, () => {
  it('tier 1 records evidence but does not require VERIFICATION.md', () => {
    const dir = project({ tier: 1 });
    record(dir, 'TASK-001', [], 'bash test.sh');
    const r = verify(dir);
    assert.strictEqual(r.status, 0);
    assert.match(r.stdout, /tier 1 phase 01-calc — VERIFICATION\.md not required/);
    assert.ok(!fs.existsSync(path.join(dir, PH, 'VERIFICATION.md')));
    assert.ok(fs.existsSync(path.join(dir, PH, 'evidence', 'index.json')));
    fs.rmSync(dir, { recursive: true, force: true });
  });
});

describe('AIDLC evidence rail — wiring', () => {
  it('feature-build verifies evidence between implement and spec review', () => {
    const y = fs.readFileSync(path.join(ROOT, 'pipelines', 'developer', 'feature-build.pipeline.yaml'), 'utf8');
    assert.match(y, /- id: verify-evidence\n    skill: aidlc-evidence-verifier[\s\S]*depends_on: \[implement\]/);
    assert.match(y, /- id: verify-spec[\s\S]*depends_on: \[verify-evidence\]/);
  });

  it('task-implementer, release-readiness-checker and quality-gate carry the AIDLC evidence rules in prompt and SKILL.md', () => {
    const want = {
      'task-implementer': /aidlc-evidence\.sh run --task/,
      'release-readiness-checker': /FAIL — no execution evidence/,
      'quality-gate': /aidlc-phase-quality-gate\.sh/,
    };
    for (const [s, re] of Object.entries(want)) {
      for (const f of ['prompt.md', 'SKILL.md']) {
        assert.match(fs.readFileSync(path.join(ROOT, 'skills', s, f), 'utf8'), re, `${s}/${f}`);
      }
    }
  });

  it('evidence tools are installed even with --no-hooks', { skip: !jqAvailable && 'jq not installed' }, () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'aidlc-evinst-'));
    execFileSync('bash', [path.join(ROOT, 'setup', 'install-role.sh'), 'qa', '--agent', 'claude-code', '--no-hooks'], { cwd: dir, stdio: 'pipe' });
    assert.ok(fs.existsSync(path.join(dir, '.claude', 'hooks', '_bin', 'aidlc-evidence.sh')));
    assert.ok(fs.existsSync(path.join(dir, '.claude', 'hooks', '_bin', 'aidlc-verify.sh')));
    assert.ok(!fs.existsSync(path.join(dir, '.claude', 'hooks', 'aidlc-pre-write-guard')));
    assert.ok(fs.existsSync(path.join(dir, '.claude', 'skills', 'aidlc-evidence-verifier', 'SKILL.md')));
    fs.rmSync(dir, { recursive: true, force: true });
  });
});
