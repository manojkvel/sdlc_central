/**
 * AIDLC phase 5 tests — decision coverage, grilling, and test-first proof.
 *   Recorder: --red must fail (exit 0 when it does, 3 when the test already passes); red runs never count as coverage.
 *   Verifier: with red_green_required, every task needs a red run before its latest green run; waivers are listed.
 *   Grill: a step between source and spec, installed for the planning roles, routed by /atticus.
 * (T05 to T07 and the W02 plan gate are covered one case per code in hooks/_test/run.sh.)
 */
'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync, execFileSync } = require('node:child_process');

const ROOT = path.resolve(__dirname, '..');
const BIN = path.join(ROOT, 'hooks', '_bin');
const PH = path.join('.track', 'phases', '01-calc');
const jq = spawnSync('jq', ['--version']).status === 0;
const bin = (dir, tool, args = []) => spawnSync('bash', [path.join(BIN, tool), ...args], { cwd: dir, encoding: 'utf8', env: { ...process.env, AIDLC_PROJECT_DIR: dir } });

function project({ redGreen = true, tasks } = {}) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'aidlc-p5-'));
  execFileSync('bash', ['-c', 'git init -q && git config user.name "Dana" && git commit -q --allow-empty -m i'], { cwd: dir });
  execFileSync('bash', [path.join(ROOT, 'setup', 'init-track.sh')], { cwd: dir, stdio: 'pipe' });
  fs.mkdirSync(path.join(dir, '.claude', 'config'), { recursive: true });
  const gc = JSON.parse(fs.readFileSync(path.join(ROOT, 'config', 'gate-config.json'), 'utf8'));
  if (!redGreen) delete gc.red_green_required;
  fs.writeFileSync(path.join(dir, '.claude', 'config', 'gate-config.json'), JSON.stringify(gc));
  fs.writeFileSync(path.join(dir, '.claude', 'sdlc-central.json'), '{"track_root":".track"}');
  fs.mkdirSync(path.join(dir, PH), { recursive: true }); fs.mkdirSync(path.join(dir, 'src'));
  fs.writeFileSync(path.join(dir, PH, 'unit.yaml'), 'id: UOW-001\nname: calc\nprofile: feature\ntier: 2\nverify_command: bash test.sh\n');
  fs.writeFileSync(path.join(dir, PH, 'SPEC.md'), '# Spec\n- AC-1: add returns the sum\n');
  fs.writeFileSync(path.join(dir, PH, 'TASKS.md'), tasks || '## TASK-001 add\n- covers AC-1\n- Verify: `bash test.sh`\n- Files: `src/calc.sh`\n');
  fs.writeFileSync(path.join(dir, 'src', 'calc.sh'), 'add(){ echo 0; }\n');
  fs.writeFileSync(path.join(dir, 'test.sh'), '. src/calc.sh; [ "$(add 2 3)" = 5 ]\n');
  const st = path.join(dir, '.track', 'state.md');
  fs.writeFileSync(st, fs.readFileSync(st, 'utf8').replace('CURRENT_PHASE: none', 'CURRENT_PHASE: 01-calc').replace('CURRENT_STAGE: intake', 'CURRENT_STAGE: execution'));
  return dir;
}
const fix = dir => fs.writeFileSync(path.join(dir, 'src', 'calc.sh'), 'add(){ echo $(($1+$2)); }\n');
const green = dir => bin(dir, 'aidlc-evidence.sh', ['run', '--task', 'TASK-001', '--suite', '--', 'bash test.sh']);
const red = dir => bin(dir, 'aidlc-evidence.sh', ['run', '--task', 'TASK-001', '--red', '--', 'bash test.sh']);
const verification = dir => fs.readFileSync(path.join(dir, PH, 'VERIFICATION.md'), 'utf8');

describe('test-first evidence', { skip: !jq && 'jq not installed' }, () => {
  it('a red run that fails exits 0 and is marked; one that passes exits 3', () => {
    const dir = project();
    const r = red(dir);
    assert.strictEqual(r.status, 0, r.stderr);
    assert.match(r.stdout, /RED confirmed/);
    const idx = JSON.parse(fs.readFileSync(path.join(dir, PH, 'evidence', 'index.json'), 'utf8'));
    assert.strictEqual(idx.entries[0].expect, 'fail');
    fix(dir);
    const r2 = red(dir);
    assert.strictEqual(r2.status, 3);
    assert.match(r2.stderr, /proves nothing/);
    assert.match(bin(dir, 'aidlc-evidence.sh', ['summary']).stdout, /red runs 2/);
  });

  it('red runs never count as coverage', () => {
    const dir = project();
    red(dir);
    assert.strictEqual(bin(dir, 'aidlc-verify.sh', ['--no-rerun', 'test']).status, 2);
    assert.match(verification(dir), /\| AC-1 \|.*FAIL.*no evidence covers/);
  });

  it('green without a red run first fails verification when red_green_required is on', () => {
    const dir = project();
    fix(dir); green(dir);
    const v = bin(dir, 'aidlc-verify.sh');
    assert.strictEqual(v.status, 2);
    assert.match(verification(dir), /## Test-first proof[\s\S]*\| TASK-001 \| FAIL \|.*no failing run before the passing one/);
  });

  it('red then green passes; a red run recorded after the green does not count', () => {
    const dir = project();
    red(dir); fix(dir); green(dir);
    assert.strictEqual(bin(dir, 'aidlc-verify.sh').status, 0, verification(dir));
    assert.match(verification(dir), /\| TASK-001 \| PASS \| E-001 then E-002 \|/);
    const late = project();
    fix(late); green(late);
    fs.writeFileSync(path.join(late, 'src', 'calc.sh'), 'add(){ echo 0; }\n'); red(late); fix(late);
    assert.strictEqual(bin(late, 'aidlc-verify.sh', ['--no-rerun', 'test']).status, 2);
  });

  it('a waived task is listed as WAIVED; without the setting there is no test-first section', () => {
    const dir = project({ tasks: '## TASK-001 add\n- covers AC-1\n- Verify: `bash test.sh`\n- Red: n/a - generated code, covered by the contract test\n' });
    fix(dir); green(dir);
    assert.strictEqual(bin(dir, 'aidlc-verify.sh').status, 0);
    assert.match(verification(dir), /\| TASK-001 \| WAIVED \| — \| n\/a - generated code/);
    const off = project({ redGreen: false });
    fix(off); green(off);
    assert.strictEqual(bin(off, 'aidlc-verify.sh').status, 0);
    assert.doesNotMatch(verification(off), /Test-first proof/);
  });
});

describe('grill and decision coverage wiring', () => {
  const pipe = fs.readFileSync(path.join(ROOT, 'pipelines', 'aidlc', 'unit-of-work.pipeline.yaml'), 'utf8');
  it('grill runs between source and spec, and spec depends on it', () => {
    assert.match(pipe, /- id: grill\n    skill: grill\n    args: "\$INPUT"\n    depends_on: \[source\]/);
    assert.match(pipe, /- id: spec\n    skill: spec-gen\n    args: "\$INPUT"\n    depends_on: \[grill\]/);
  });
  it('the grill prompt batches questions with recommendations and records D ids', () => {
    const p = fs.readFileSync(path.join(ROOT, 'skills', 'grill', 'prompt.md'), 'utf8');
    for (const s of ['every** question', 'recommended answer', '## Decisions', '## Open questions', '## GRILL COMPLETE', 'Facts are your job']) assert.ok(p.includes(s), s);
    assert.ok(fs.existsSync(path.join(ROOT, 'skills', 'grill', 'SKILL.md')));
  });
  it('prompts carry the new rules: plan-gen carries decisions, task-gen asks for Verify, task-implementer records --red', () => {
    assert.match(fs.readFileSync(path.join(ROOT, 'skills', 'plan-gen', 'prompt.md'), 'utf8'), /Carry every decision/);
    assert.match(fs.readFileSync(path.join(ROOT, 'skills', 'task-gen', 'prompt.md'), 'utf8'), /\*\*Verify:\*\*/);
    assert.match(fs.readFileSync(path.join(ROOT, 'skills', 'task-implementer', 'prompt.md'), 'utf8'), /--red/);
    assert.match(fs.readFileSync(path.join(ROOT, 'skills', 'plan-check', 'prompt.md'), 'utf8'), /T05/);
    assert.match(fs.readFileSync(path.join(ROOT, 'skills', 'atticus', 'prompt.md'), 'utf8'), /grill me/);
  });
  it('the developer role installs grill', { skip: !jq && 'jq not installed' }, () => {
    const d = fs.mkdtempSync(path.join(os.tmpdir(), 'aidlc-p5i-'));
    execFileSync('bash', [path.join(ROOT, 'setup', 'install-role.sh'), 'developer', '--agent', 'claude-code'], { cwd: d, stdio: 'pipe' });
    assert.ok(fs.existsSync(path.join(d, '.claude', 'skills', 'grill', 'SKILL.md')));
    assert.ok(fs.existsSync(path.join(d, '.claude', 'skills', 'atticus', 'SKILL.md')));
  });
});
