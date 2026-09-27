/**
 * Measurement Bench tests: metrics carry test-first, gate wait and a sample marker; the observation window
 * is taken from timestamps, not line order; the console build writes bench.html beside index.html with the
 * shared renderer and the data inlined safely; atticus bench builds both in a real project.
 */
'use strict';

const { describe, it, before } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const vm = require('node:vm');
const { spawnSync, execFileSync } = require('node:child_process');

const ROOT = path.resolve(__dirname, '..');
const BIN = path.join(ROOT, 'hooks', '_bin');
const jq = spawnSync('jq', ['--version']).status === 0;
const py = spawnSync('python3', ['--version']).status === 0;
const run = (dir, tool, args = []) => spawnSync('bash', [path.join(BIN, tool), ...args], { cwd: dir, encoding: 'utf8', env: { ...process.env, AIDLC_PROJECT_DIR: dir } });

describe('measurement bench', { skip: (!jq || !py) && 'jq and python3 required' }, () => {
  let W, A, B, M;
  before(() => {
    W = fs.mkdtempSync(path.join(os.tmpdir(), 'bench-'));
    A = path.join(W, 'payments'); B = path.join(W, 'search');
    execFileSync('python3', [path.join(ROOT, 'tests', 'fixtures', 'make-sample-track.py'), A, 'Payments', '--seed', '7', '--units', '10']);
    execFileSync('python3', [path.join(ROOT, 'tests', 'fixtures', 'make-sample-track.py'), B, 'Search', '--seed', '11', '--units', '6']);
    for (const d of [A, B]) { assert.strictEqual(run(d, 'aidlc-metrics.sh').status, 0); assert.strictEqual(run(d, 'aidlc-portfolio.sh').status, 0); }
    M = JSON.parse(fs.readFileSync(path.join(A, 'docs', 'aidlc', 'metrics', 'metrics.json'), 'utf8'));
  });

  it('marks a sample track and takes the observation window from timestamps, not line order', () => {
    assert.strictEqual(M.sample, true);
    assert.ok(M.dora.days_observed > 30, `window ${M.dora.days_observed}`);
    assert.ok(M.dora.deployment_frequency_per_30d > 0);
    assert.strictEqual(M.dora.releases, 10);
  });

  it('computes test first per unit and overall, with counts', () => {
    const tf = M.phases.map(p => p.test_first).filter(Boolean);
    assert.strictEqual(tf.length, 10);
    for (const t of tf) assert.ok(t.proven <= t.tasks - t.waived);
    const tot = M.quality.test_first_tasks;
    assert.strictEqual(tot.tasks, tf.reduce((s, t) => s + t.tasks, 0));
    assert.ok(Math.abs(M.quality.test_first_rate - tot.proven / (tot.tasks - tot.waived)) < 1e-9);
  });

  it('computes gate wait per unit and as a share of lead time', () => {
    const gw = M.phases.filter(p => p.tier > 1).map(p => p.gate_wait_hours);
    assert.ok(gw.every(x => typeof x === 'number' && x > 0), JSON.stringify(gw));
    assert.ok(M.governance.gate_wait_share > 0 && M.governance.gate_wait_share < 1);
  });

  it('a real track without sample data reports nulls, not zeros', () => {
    const d = fs.mkdtempSync(path.join(os.tmpdir(), 'bench-real-'));
    execFileSync('bash', ['-c', 'git init -q'], { cwd: d });
    execFileSync('bash', [path.join(ROOT, 'setup', 'init-track.sh')], { cwd: d, stdio: 'pipe' });
    fs.mkdirSync(path.join(d, '.claude')); fs.writeFileSync(path.join(d, '.claude', 'sdlc-central.json'), '{"track_root":".track"}');
    assert.strictEqual(run(d, 'aidlc-metrics.sh').status, 0);
    const m = JSON.parse(fs.readFileSync(path.join(d, 'docs', 'aidlc', 'metrics', 'metrics.json'), 'utf8'));
    assert.strictEqual(m.sample, undefined);
    assert.strictEqual(m.quality.test_first_rate, null);
    assert.strictEqual(m.governance.gate_wait_share, null);
    assert.strictEqual(m.cost.tokens_total, null);
  });

  it('the console build writes index.html with a Bench tab and bench.html with the renderer and data inlined', () => {
    const dept = path.join(W, 'dept');
    assert.strictEqual(run(A, 'aidlc-portfolio.sh', ['--merge', dept, path.join(A, 'docs/aidlc/console-data'), path.join(B, 'docs/aidlc/console-data')]).status, 0);
    const out = path.join(W, 'out', 'index.html');
    const r = run(A, 'aidlc-console.sh', ['--data', dept, '--out', out]);
    assert.strictEqual(r.status, 0, r.stderr);
    const bench = fs.readFileSync(path.join(W, 'out', 'bench.html'), 'utf8'), idx = fs.readFileSync(out, 'utf8');
    for (const html of [bench, idx]) {
      assert.ok(!html.includes('/*__AIDLC_DATA__*/') && !html.includes('/*__AIDLC_BENCH_JS__*/'), 'placeholders filled');
      assert.ok(html.includes('window.AtticusBench = { render }'));
      const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m => m[1]);
      for (const s of scripts) new vm.Script(s);   // every inlined script parses; a stray </script> would break this
    }
    assert.match(idx, /\['bench','Bench'\]/);
    assert.match(bench, /"squads":\[/);
    assert.match(bench, /"sample":true/);
  });

  it('atticus bench builds both pages in a real project, and the tools install with the hooks', () => {
    const d = fs.mkdtempSync(path.join(os.tmpdir(), 'bench-cli-'));
    execFileSync('bash', ['-c', 'git init -q && mkdir .claude'], { cwd: d });
    assert.strictEqual(spawnSync('bash', [path.join(ROOT, 'bin', 'atticus'), 'init', '-y', '--experimental'], { cwd: d, encoding: 'utf8' }).status, 0);
    for (const f of ['bench.js', 'bench.html', 'console.html']) assert.ok(fs.existsSync(path.join(d, '.claude', 'hooks', '_bin', f)), f);
    const r = spawnSync('bash', [path.join(ROOT, 'bin', 'atticus'), 'bench'], { cwd: d, encoding: 'utf8' });
    assert.strictEqual(r.status, 0, r.stderr);
    assert.match(r.stdout, /Measurement Bench: .*bench\.html/);
    assert.ok(fs.existsSync(path.join(d, 'docs', 'aidlc', 'console', 'bench.html')));
    assert.ok(fs.existsSync(path.join(d, 'docs', 'aidlc', 'console', 'index.html')));
  });

  it('the renderer shows a dash for missing sources and never ranks squads', () => {
    const js = fs.readFileSync(path.join(ROOT, 'console', 'bench.js'), 'utf8');
    assert.match(js, /Squads are never ranked/);
    assert.match(js, /isNum\(x\) \? .* : '—'/);
    assert.match(js, /modelled/);
  });
});
