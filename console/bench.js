/* Atticus Measurement Bench renderer, shared by the console's Bench tab and the standalone bench.html.
   Input: metrics.json from aidlc-metrics.sh (one squad), or {squads:[...]} from aidlc-portfolio.sh --merge.
   Every figure is read from that file; nothing is typed in except the value model's planning inputs,
   which are labelled "modelled" and kept in this viewer's browser only. No network, no libraries. */
(function () {
  'use strict';
  const NS = 'http://www.w3.org/2000/svg';
  const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const isNum = x => typeof x === 'number' && isFinite(x);
  const fmt = (x, d = 1) => isNum(x) ? (+x).toLocaleString('en-GB', { minimumFractionDigits: d, maximumFractionDigits: d }) : '—';
  const pct = (x, d = 0) => isNum(x) ? fmt(x * 100, d) : '—';
  const sum = a => a.reduce((s, x) => s + (isNum(x) ? x : 0), 0);
  const median = a => { const s = a.filter(isNum).sort((x, y) => x - y); if (!s.length) return null; const m = s.length >> 1; return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2; };
  const niceMax = v => { if (!(v > 0)) return 1; const p = Math.pow(10, Math.floor(Math.log10(v))); const n = v / p; return (n <= 1 ? 1 : n <= 2 ? 2 : n <= 2.5 ? 2.5 : n <= 5 ? 5 : 10) * p; };
  const store = { get(k, d) { try { const v = localStorage.getItem('atticus.bench.' + k); return v == null ? d : JSON.parse(v); } catch (e) { return d; } },
                  set(k, v) { try { localStorage.setItem('atticus.bench.' + k, JSON.stringify(v)); } catch (e) {} } };

  const STAGE_GROUPS = [
    ['Spec', ['intake', 'source', 'grill', 'spec']],
    ['Design and risk', ['design', 'risk']],
    ['Plan and check', ['planning', 'plan', 'check-plan', 'tasks']],
    ['Build', ['execution', 'implement']],
    ['Verify and release', ['verification', 'verify', 'review', 'governance', 'scorecard', 'release']]
  ];
  const SERIES = ['var(--s1)', 'var(--s2)', 'var(--s3)', 'var(--s4)', 'var(--s5)'];
  const groupOf = st => { const i = STAGE_GROUPS.findIndex(g => g[1].includes(st)); return i < 0 ? STAGE_GROUPS.length - 1 : i; };

  const STYLE = `
.ab{--ab-gap:14px}
.ab .ab-h{display:flex;flex-wrap:wrap;gap:8px 20px;align-items:baseline;justify-content:space-between;margin:22px 0 8px}
.ab .ab-h h2{margin:0;font-size:19px}.ab .ab-sub{color:var(--ink2);font-size:13px;max-width:78ch;margin:0 0 12px}
.ab .ab-kpis{display:grid;gap:10px;grid-template-columns:repeat(auto-fill,minmax(min(100%,165px),1fr))}
.ab .ab-kpi{background:var(--surface);border:1px solid var(--rule2);border-radius:10px;padding:10px 12px}
.ab .ab-kpi .k{font-size:12px;color:var(--ink3);font-weight:500}.ab .ab-kpi .n{font:600 24px/1.15 var(--mono);margin-top:3px;font-variant-numeric:tabular-nums}
.ab .ab-kpi .n small{font-size:12.5px;color:var(--ink3);font-weight:500;margin-left:3px}
.ab .ab-kpi .d{font-size:12px;margin-top:4px;color:var(--ink2)}.ab .ab-kpi .d.ab-better{color:var(--good)}.ab .ab-kpi .d.ab-worse{color:var(--bad)}
.ab .ab-kpi .s{font:10.5px var(--mono);color:var(--ink3);margin-top:5px;word-break:break-word}
.ab .ab-grid{display:grid;gap:var(--ab-gap);grid-template-columns:repeat(auto-fill,minmax(min(100%,460px),1fr))}
.ab .ab-panel{background:var(--surface);border:1px solid var(--rule2);border-radius:10px;padding:14px 16px;min-width:0}
.ab .ab-panel h3{margin:0 0 4px;font-size:14px}.ab .ab-panel .note{font-size:12px;color:var(--ink3);margin:0 0 8px}
.ab svg.ab-chart{width:100%;height:auto;display:block}.ab svg.ab-chart text{fill:var(--ink2);font-size:11.5px;font-family:inherit}
.ab svg.ab-chart .gl{stroke:var(--rule2);stroke-width:1}.ab svg.ab-chart .mk{cursor:default}.ab svg.ab-chart .mk:focus{outline:2px solid var(--brand)}
.ab .ab-legend{display:flex;flex-wrap:wrap;gap:4px 14px;font-size:12px;color:var(--ink2);margin-top:8px}
.ab .ab-legend i{display:inline-block;width:11px;height:11px;border-radius:3px;margin-right:5px;vertical-align:-1px}
.ab .ab-empty{color:var(--ink3);font-size:13px;font-style:italic;padding:18px 4px}
.ab .ab-tag{display:inline-block;font:10.5px var(--mono);letter-spacing:.05em;text-transform:uppercase;padding:1px 7px;border-radius:4px;border:1px solid var(--rule);color:var(--ink2);vertical-align:middle}
.ab .ab-tag.measured{border-color:var(--good);color:var(--good);background:var(--good-wash)}
.ab .ab-tag.modelled{border-color:var(--warn);color:var(--warn);background:var(--warn-wash)}
.ab .ab-tag.sample{border-color:var(--bad);color:var(--bad);background:var(--bad-wash)}
.ab table{width:100%;border-collapse:collapse;font-size:12.5px;font-variant-numeric:tabular-nums}
.ab th,.ab td{text-align:left;padding:6px 8px;border-bottom:1px solid var(--rule2);vertical-align:top}.ab th{color:var(--ink2);font-size:11.5px}
.ab td.num,.ab th.num{text-align:right;font-family:var(--mono)}.ab .tw{overflow-x:auto}
.ab details{margin-top:8px}.ab summary{cursor:pointer;color:var(--brand);font-size:12.5px}
.ab .ab-fields{display:grid;gap:10px;grid-template-columns:repeat(auto-fill,minmax(200px,1fr))}
.ab .ab-fields label{display:block;font-size:12px;color:var(--ink2);margin-bottom:3px}
.ab .ab-fields input{width:100%;font:13px var(--mono);padding:6px 8px;border:1px solid var(--rule);border-radius:6px;background:var(--surface2);color:var(--ink)}
.ab .ab-fields .hint{font-size:11px;color:var(--ink3);margin-top:2px}
.ab .ab-scope{display:flex;flex-wrap:wrap;gap:6px;align-items:center;margin:10px 0}
.ab .ab-scope button,.ab button.ab-btn{font:inherit;font-size:12.5px;padding:5px 10px;border-radius:99px;border:1px solid var(--rule);background:var(--surface);color:var(--ink2);cursor:pointer}
.ab .ab-scope button[aria-pressed=true]{background:var(--brand-wash);border-color:var(--brand);color:var(--brand);font-weight:600}
.ab .ab-banner{border:1px solid var(--bad);background:var(--bad-wash);color:var(--ink);border-radius:8px;padding:8px 12px;font-size:13px;margin:10px 0}
.ab-tip{position:fixed;z-index:50;pointer-events:none;background:var(--ink);color:var(--surface);font-size:12px;line-height:1.4;padding:7px 9px;border-radius:6px;max-width:260px;opacity:0;transition:opacity .08s}
@media (max-width:560px){.ab .ab-kpi .n{font-size:21px}}`;

  let tip;
  function ensureChrome() {
    if (!document.getElementById('ab-style')) { const s = document.createElement('style'); s.id = 'ab-style'; s.textContent = STYLE; document.head.appendChild(s); }
    if (!tip) { tip = document.createElement('div'); tip.className = 'ab-tip'; tip.setAttribute('role', 'status'); document.body.appendChild(tip); }
  }
  function moveTip(e) { const p = 12; let x = e.clientX + p, y = e.clientY + p; const r = tip.getBoundingClientRect(); if (x + r.width > innerWidth - 8) x = e.clientX - r.width - p; if (y + r.height > innerHeight - 8) y = e.clientY - r.height - p; tip.style.left = x + 'px'; tip.style.top = y + 'px'; }
  function hover(node, html) {
    node.classList.add('mk'); node.setAttribute('tabindex', '0');
    node.addEventListener('mouseenter', e => { tip.innerHTML = html; tip.style.opacity = 1; moveTip(e); });
    node.addEventListener('mousemove', moveTip);
    node.addEventListener('mouseleave', () => { tip.style.opacity = 0; });
    node.addEventListener('focus', () => { const r = node.getBoundingClientRect(); tip.innerHTML = html; tip.style.opacity = 1; moveTip({ clientX: r.left + r.width / 2, clientY: r.top }); });
    node.addEventListener('blur', () => { tip.style.opacity = 0; });
  }
  function el(tag, attrs, parent) { const e = document.createElementNS(NS, tag); for (const k in attrs) e.setAttribute(k, attrs[k]); if (parent) parent.appendChild(e); return e; }
  function txt(parent, x, y, s, attrs = {}) { const t = el('text', Object.assign({ x, y }, attrs), parent); t.textContent = s; return t; }
  const legend = items => `<div class="ab-legend">${items.map(([c, l]) => `<span><i style="background:${c}"></i>${esc(l)}</span>`).join('')}</div>`;

  /* ---------- charts ---------- */
  // Horizontal bars, one series. rows: [{label, value, tip}]
  const labelWidth = rows => Math.min(200, Math.max(70, 12 + 6.6 * Math.max(...rows.map(r => Math.min(30, String(r.label).length)))));
  const clip = s => (s = String(s)).length > 30 ? s.slice(0, 29) + '…' : s;
  const widthOf = svg => Math.max(300, Math.min(760, Math.round((svg.parentNode && svg.parentNode.clientWidth ? svg.parentNode.clientWidth - 32 : 560))));
  function hbar(svg, rows, { unit = '', color = SERIES[0] } = {}) {
    const W = widthOf(svg), rh = 26, T = 6, B = 22, H = T + rows.length * rh + B, L = labelWidth(rows), R = 56;
    svg.setAttribute('viewBox', `0 0 ${W} ${H}`);
    const max = niceMax(Math.max(...rows.map(r => r.value), 0)), sx = (W - L - R) / max;
    [0, max / 2, max].forEach(v => { const x = L + v * sx; el('line', { x1: x, x2: x, y1: T, y2: H - B, class: 'gl' }, svg); txt(svg, x, H - 6, fmt(v, v % 1 ? 1 : 0), { 'text-anchor': 'middle' }); });
    rows.forEach((r, i) => {
      const y = T + i * rh + 4, w = Math.max(r.value > 0 ? 2 : 0, r.value * sx);
      txt(svg, L - 8, y + 13, clip(r.label), { 'text-anchor': 'end' });
      const b = el('rect', { x: L, y, width: w, height: rh - 10, rx: 3, fill: color }, svg);
      txt(svg, L + w + 6, y + 13, fmt(r.value, r.value % 1 ? 1 : 0) + unit, { style: 'fill:var(--ink)' });
      hover(b, r.tip || `<b>${esc(r.label)}</b><br>${fmt(r.value, 1)}${esc(unit)}`);
    });
  }
  // Horizontal stacked bars. rows: [{label, parts:[number per series], tip}], names: series names
  function stacked(svg, rows, names, { unit = '', colors = SERIES } = {}) {
    const W = widthOf(svg), rh = 24, T = 6, B = 22, H = T + rows.length * rh + B, L = labelWidth(rows), R = 50;
    svg.setAttribute('viewBox', `0 0 ${W} ${H}`);
    const max = niceMax(Math.max(...rows.map(r => sum(r.parts)), 0)), sx = (W - L - R) / max;
    [0, max / 2, max].forEach(v => { const x = L + v * sx; el('line', { x1: x, x2: x, y1: T, y2: H - B, class: 'gl' }, svg); txt(svg, x, H - 6, fmt(v, v % 1 ? 1 : 0), { 'text-anchor': 'middle' }); });
    rows.forEach((r, i) => {
      const y = T + i * rh + 4; let x = L;
      txt(svg, L - 8, y + 12, clip(r.label), { 'text-anchor': 'end' });
      r.parts.forEach((v, k) => {
        if (!(v > 0)) return;
        const w = Math.max(2, v * sx);
        const seg = el('rect', { x, y, width: Math.max(1, w - 2), height: rh - 9, rx: 2, fill: colors[k] }, svg);  // 2px surface gap between segments
        hover(seg, `<b>${esc(r.label)}</b><br>${esc(names[k])}: ${fmt(v, v % 1 ? 1 : 0)}${esc(unit)}`);
        x += w;
      });
      txt(svg, x + 4, y + 12, fmt(sum(r.parts), sum(r.parts) % 1 ? 1 : 0) + unit, { style: 'fill:var(--ink)' });
    });
  }
  // Lead time per released unit over time, with the baseline as a dashed reference line.
  function trend(svg, pts, baseline) {
    const W = widthOf(svg), H = 230, L = 40, R = 16, T = 12, B = 30;
    svg.setAttribute('viewBox', `0 0 ${W} ${H}`);
    const xs = pts.map(p => p.t), t0 = Math.min(...xs), t1 = Math.max(...xs), span = Math.max(1, t1 - t0);
    const max = niceMax(Math.max(...pts.map(p => p.v), isNum(baseline) ? baseline : 0));
    const X = t => pts.length === 1 ? (L + W - R) / 2 : L + (t - t0) / span * (W - L - R), Y = v => H - B - v / max * (H - T - B);
    [0, max / 2, max].forEach(v => { el('line', { x1: L, x2: W - R, y1: Y(v), y2: Y(v), class: 'gl' }, svg); txt(svg, L - 6, Y(v) + 4, fmt(v, v % 1 ? 1 : 0), { 'text-anchor': 'end' }); });
    const day = t => new Date(t).toISOString().slice(0, 10);
    txt(svg, X(t0), H - 8, day(t0), { 'text-anchor': pts.length === 1 ? 'middle' : 'start' });
    if (pts.length > 1) txt(svg, X(t1), H - 8, day(t1), { 'text-anchor': 'end' });
    if (isNum(baseline)) {
      el('line', { x1: L, x2: W - R, y1: Y(baseline), y2: Y(baseline), stroke: 'var(--s2)', 'stroke-width': 2, 'stroke-dasharray': '5 4' }, svg);
      txt(svg, W - R, Y(baseline) - 5, 'baseline ' + fmt(baseline, 1) + ' d', { 'text-anchor': 'end', style: 'fill:var(--ink)' });
    }
    if (pts.length > 1) el('polyline', { points: pts.map(p => X(p.t) + ',' + Y(p.v)).join(' '), fill: 'none', stroke: 'var(--s1)', 'stroke-width': 2 }, svg);
    pts.forEach(p => { const c = el('circle', { cx: X(p.t), cy: Y(p.v), r: 5, fill: 'var(--s1)', stroke: 'var(--surface)', 'stroke-width': 2 }, svg);
      hover(c, `<b>${esc(p.label)}</b> · tier ${esc(p.tier)}<br>released ${day(p.t)}<br>lead time ${fmt(p.v, 1)} days`); });
  }

  /* ---------- data ---------- */
  function unitsOf(m) { return (m.phases || []).map(p => ({ ...p, squad: m.squad })); }
  function tokensOf(p) { const t = p.tokens; return t ? (t.input || 0) + (t.output || 0) + (t.cache_read || 0) + (t.cache_creation || 0) : null; }
  function delta(now, base, lowerBetter, d = 1, suffix = '') {
    if (!isNum(now) || !isNum(base)) return { text: isNum(base) ? 'baseline ' + fmt(base, d) + suffix : 'no baseline in baseline.json', cls: '' };
    const diff = now - base, better = lowerBetter ? diff < 0 : diff > 0;
    if (Math.abs(diff) < 1e-9) return { text: 'same as baseline ' + fmt(base, d) + suffix, cls: '' };
    const rel = base !== 0 ? ' (' + (diff > 0 ? '+' : '−') + fmt(Math.abs(diff / base) * 100, 0) + '%)' : '';
    const dd = Math.abs(diff) < Math.pow(10, -d) ? d + 1 : d;
    return { text: (diff > 0 ? '+' : '−') + fmt(Math.abs(diff), dd) + suffix + rel + ' vs baseline ' + fmt(base, d) + suffix, cls: better ? 'ab-better' : 'ab-worse' };
  }
  function kpi(label, value, unit, sub, dl, src) {
    return `<div class="ab-kpi"><div class="k">${esc(label)}</div><div class="n">${value}${unit && value !== '—' ? `<small>${esc(unit)}</small>` : ''}</div>`
      + (dl ? `<div class="d ${dl.cls}">${esc(dl.text)}</div>` : '') + (sub ? `<div class="d">${esc(sub)}</div>` : '') + `<div class="s">${esc(src)}</div></div>`;
  }

  /* ---------- sections ---------- */
  function kpis(m) {
    const d = m.dora || {}, g = m.governance || {}, q = m.quality || {}, c = m.cost || {}, b = m.baseline || {};
    const units = unitsOf(m), released = units.filter(u => isNum(u.lead_time_days));
    const tf = q.test_first_tasks || {};
    const t2 = (c.per_tier || []).find(x => x.tier === 2);
    return '<div class="ab-kpis">'
      + kpi('Lead time, median', fmt(d.lead_time_days_median, 1), 'days', released.length + ' released unit(s)', delta(d.lead_time_days_median, b.lead_time_days, true, 1, ' d'), 'lineage.md: first event → stage.entered: released')
      + kpi('Deployment frequency', fmt(d.deployment_frequency_per_30d, 1), 'per 30 days', (d.releases || 0) + ' release(s) over ' + fmt(d.days_observed, 1) + ' days observed', delta(d.deployment_frequency_per_30d, b.deployment_frequency_per_30d, false, 1), 'lineage.md release events')
      + kpi('Change failure rate', pct(d.change_failure_rate), '%', isNum(d.incidents) ? d.incidents + ' incident(s) linked to a phase' : 'needs incidents.json (incident-triager)', delta(isNum(d.change_failure_rate) ? d.change_failure_rate * 100 : null, isNum(b.change_failure_rate) ? b.change_failure_rate * 100 : null, true, 0, ' pts'), 'incidents.json ÷ releases')
      + kpi('Time to restore, median', fmt(d.time_to_restore_hours_median, 1), 'hours', isNum(d.time_to_restore_hours_median) ? '' : 'needs restore_hours in incidents.json', null, 'incidents.json')
      + kpi('Rework rate', pct(q.rework_rate), '%', 'decisions sending work back', delta(isNum(q.rework_rate) ? q.rework_rate * 100 : null, isNum(b.rework_rate) ? b.rework_rate * 100 : null, true, 0, ' pts'), 'human-decisions.md: CHANGES / VERIFICATION REQUESTED')
      + kpi('Test first', pct(q.test_first_rate), '%', (tf.proven || 0) + ' of ' + ((tf.tasks || 0) - (tf.waived || 0)) + ' tasks failed before passing' + (tf.waived ? ', ' + tf.waived + ' waived' : ''), null, 'evidence/index.json red → green per task')
      + kpi('Evidence coverage', pct(q.evidence_coverage), '%', 'criteria with fresh passing evidence', null, 'sealed VERIFICATION.md')
      + kpi('Scorecard first pass', pct(q.scorecard_first_pass_rate), '%', 'units approved at the first scorecard', null, 'gate-history.json release-scorecard')
      + kpi('Structured approvals', pct(g.structured_approval_rate), '%', (g.decisions_accepted || 0) + ' accepted, ' + (g.vague_attempts_rejected || 0) + ' vague attempts refused', null, 'human-decisions.md')
      + kpi('Gate wait share', pct(g.gate_wait_share, 1), '% of lead time', 'checkpoint → decision, released units', null, 'lineage.md checkpoint and decision events')
      + kpi('Asserted identity', fmt(g.asserted_identity_decisions, 0), 'decisions', 'not authenticated by the decision bot', null, 'human-decisions.md identity')
      + kpi('Tokens per tier 2 unit', t2 ? fmt(t2.tokens_per_unit / 1000, 0) : '—', 'k tokens', t2 ? t2.units + ' unit(s) measured' : (c.note || 'no usage recorded'), null, 'runs/usage (Claude Code Stop hook)')
      + '</div>';
  }

  function panel(title, note, id, empty) { return `<div class="ab-panel"><h3>${esc(title)}</h3><p class="note">${esc(note)}</p>${empty ? `<div class="ab-empty">${esc(empty)}</div>` : `<svg class="ab-chart" id="${id}" role="img" aria-label="${esc(title)}"></svg>`}<div id="${id}-legend"></div></div>`; }

  function charts(root, m, prefix) {
    const units = unitsOf(m);
    const stageRows = units.map(u => { const parts = STAGE_GROUPS.map(() => 0); Object.entries(u.stage_days || {}).forEach(([s, v]) => { parts[groupOf(s)] += +v || 0; }); return { label: u.phase, parts }; }).filter(r => sum(r.parts) > 0);
    const rel = units.filter(u => isNum(u.lead_time_days) && u.released_at).map(u => ({ t: Date.parse(u.released_at), v: u.lead_time_days, label: u.phase, tier: u.tier })).filter(p => isFinite(p.t)).sort((a, b) => a.t - b.t);
    const lat = Object.entries((m.governance || {}).approval_latency || {}).map(([gname, v]) => ({ label: gname, value: v.mean_hours, tip: `<b>${esc(gname)}</b><br>mean ${fmt(v.mean_hours, 1)} h over ${v.n} decision(s)` })).sort((a, b) => b.value - a.value);
    const blocks = ((m.governance || {}).guardrail_blocks || []).map(x => ({ label: x.code + ' ' + String(x.hook).replace(/^aidlc-/, ''), value: x.count })).sort((a, b) => b.value - a.value).slice(0, 12);
    const tfRows = units.filter(u => u.test_first && u.test_first.tasks).map(u => ({ label: u.phase, parts: [u.test_first.proven, u.test_first.tasks - u.test_first.proven - u.test_first.waived, u.test_first.waived] }));
    const tokRows = units.map(u => ({ label: u.phase, value: tokensOf(u) })).filter(r => isNum(r.value) && r.value > 0).map(r => ({ ...r, value: r.value / 1000 }));
    const P = id => prefix + id;
    let h = '<div class="ab-grid">'
      + panel('Days per stage, per unit', 'Time between stage changes in lineage. The current stage of an open unit is not counted yet.', P('stages'), stageRows.length ? '' : 'No stage changes recorded yet. The runner and atticus start write stage.entered events.')
      + panel('Lead time per released unit', 'Days from a unit\'s first lineage event to its release, against the squad\'s own baseline. All tiers; hover a point for its tier.', P('trend'), rel.length ? '' : 'No released units yet. A unit counts once lineage records stage.entered: released.')
      + panel('Gate wait by gate', 'Mean hours from a published checkpoint to the decision that closed it.', P('latency'), lat.length ? '' : 'No checkpoint and decision pairs yet. They appear once gates are decided through the approval guard or the decision bot.')
      + panel('Guardrail blocks by code', 'What the hooks stopped. A flat zero with active work usually means hooks are not wired.', P('blocks'), blocks.length ? '' : 'No blocks recorded in guardrail-log.md.')
      + panel('Test first, per unit', 'Tasks whose new test was recorded failing before it passed.', P('tf'), tfRows.length ? '' : 'No TASKS.md with tasks yet.')
      + panel('Tokens per unit', 'Measured model tokens per unit (input, output and cache), in thousands.', P('tokens'), tokRows.length ? '' : ((m.cost || {}).note || 'No usage recorded.'))
      + '</div>';
    root.insertAdjacentHTML('beforeend', h);
    const S = id => root.querySelector('[id="' + P(id) + '"]');
    if (stageRows.length) { stacked(S('stages'), stageRows, STAGE_GROUPS.map(g => g[0]), { unit: ' d' }); S('stages').nextElementSibling.innerHTML = legend(STAGE_GROUPS.map((g, i) => [SERIES[i], g[0]])); }
    if (rel.length) { trend(S('trend'), rel, (m.baseline || {}).lead_time_days); S('trend').nextElementSibling.innerHTML = legend([[SERIES[0], 'Lead time (days)']].concat(isNum((m.baseline || {}).lead_time_days) ? [[SERIES[1], 'Baseline']] : [])); }
    if (lat.length) hbar(S('latency'), lat, { unit: ' h' });
    if (blocks.length) hbar(S('blocks'), blocks, {});
    if (tfRows.length) { stacked(S('tf'), tfRows, ['Failed first, then passed', 'No red run yet', 'Waived'], { colors: [SERIES[0], SERIES[1], SERIES[3]] }); S('tf').nextElementSibling.innerHTML = legend([[SERIES[0], 'Failed first, then passed'], [SERIES[1], 'No red run yet'], [SERIES[3], 'Waived']]); }
    if (tokRows.length) hbar(S('tokens'), tokRows, { unit: 'k' });
  }

  function unitTable(m) {
    const units = unitsOf(m);
    if (!units.length) return '';
    const rows = units.map(u => `<tr><td>${esc(u.phase)}</td><td class="num">${esc(u.tier)}</td><td>${esc(u.profile || '—')}</td><td class="num">${fmt(u.lead_time_days, 1)}</td>`
      + `<td class="num">${u.decisions ? u.decisions.total : '—'}</td><td class="num">${u.decisions ? u.decisions.rework : '—'}</td>`
      + `<td class="num">${u.evidence && isNum(u.evidence.criteria_total) ? u.evidence.criteria_pass + '/' + u.evidence.criteria_total : '—'}</td>`
      + `<td class="num">${u.test_first ? u.test_first.proven + '/' + (u.test_first.tasks - u.test_first.waived) : '—'}</td>`
      + `<td>${esc(u.scorecard && u.scorecard.first_pass != null ? (u.scorecard.first_pass ? 'first pass' : 'blocked first') : '—')}</td>`
      + `<td class="num">${fmt(u.gate_wait_hours, 1)}</td><td class="num">${u.guardrail_blocks}</td><td class="num">${isNum(tokensOf(u)) ? fmt(tokensOf(u) / 1000, 0) + 'k' : '—'}</td></tr>`).join('');
    return `<details><summary>Table of every unit (${units.length})</summary><div class="tw"><table><thead><tr><th>Unit</th><th class="num">Tier</th><th>Profile</th><th class="num">Lead time (d)</th><th class="num">Decisions</th><th class="num">Rework</th><th class="num">Criteria</th><th class="num">Test first</th><th>Scorecard</th><th class="num">Gate wait (h)</th><th class="num">Blocks</th><th class="num">Tokens</th></tr></thead><tbody>${rows}</tbody></table></div></details>`;
  }

  /* ---------- value model (modelled; seeded from measured values) ---------- */
  function valueModel(root, m, key) {
    const d = m.dora || {}, g = m.governance || {}, c = m.cost || {}, b = m.baseline || {};
    const t2 = (c.per_tier || []).find(x => x.tier === 2) || (c.per_tier || [])[0];
    const seed = {
      base: isNum(b.lead_time_days) ? b.lead_time_days : '', now: isNum(d.lead_time_days_median) ? +d.lead_time_days_median.toFixed(1) : '',
      units: isNum(d.deployment_frequency_per_30d) && d.deployment_frequency_per_30d > 0 ? Math.round(d.deployment_frequency_per_30d * 12) : 12,
      squads: 1, fte: 1, gate: isNum(g.gate_wait_share) ? +(g.gate_wait_share * 100).toFixed(1) : '',
      tokens: t2 ? Math.round(t2.tokens_per_unit / 1000) : '', price: 3
    };
    const saved = store.get('model.' + key, null);
    const v = Object.assign({}, seed, saved || {});
    const F = [['base', 'Baseline lead time (days)', 'baseline.json lead_time_days'], ['now', 'Lead time now (days)', 'measured median'], ['units', 'Units per squad per year', 'from measured release rate, else 12'],
               ['squads', 'Squads', 'squads adopting'], ['fte', 'Engineers per unit (FTE)', 'people working a unit at once'], ['gate', 'Gate wait (% of lead time)', 'measured share, inside lead time'],
               ['tokens', 'Tokens per unit (thousands)', 'measured, tier 2'], ['price', 'Blended price per million tokens', 'your contract rate']];
    const box = document.createElement('div'); box.className = 'ab-panel';
    box.innerHTML = `<h3>Planning inputs <span class="ab-tag modelled">modelled</span></h3><p class="note">Seeded from the measured values above. Changes stay in this browser only. This is a sizing aid, not a benefits claim.</p>`
      + `<div class="ab-fields">${F.map(([k, l, h]) => `<div><label for="abm-${key}-${k}">${esc(l)}</label><input id="abm-${key}-${k}" type="number" step="any" min="0" value="${esc(v[k])}"><div class="hint">${esc(h)}${String(seed[k]) !== String(v[k]) && seed[k] !== '' ? ' · measured ' + esc(seed[k]) : ''}</div></div>`).join('')}</div>`
      + `<div style="margin-top:10px"><button type="button" class="ab-btn" id="abm-${key}-reset">Reset to measured values</button></div><div class="ab-kpis" style="margin-top:12px" id="abm-${key}-out"></div>`;
    root.appendChild(box);
    const read = () => { const o = {}; F.forEach(([k]) => { const x = parseFloat(box.querySelector('#abm-' + key + '-' + k).value); o[k] = isFinite(x) ? x : null; }); return o; };
    const calc = () => {
      const x = read(); store.set('model.' + key, x);
      const out = box.querySelector('#abm-' + key + '-out');
      if (!isNum(x.base) || !isNum(x.now) || x.base <= 0) { out.innerHTML = '<div class="ab-empty">Enter a baseline and a current lead time to size the change. Record the baseline in .track/baseline.json so it is measured, not typed.</div>'; return; }
      const workFrac = 5 / 7, perUnit = (x.base - x.now) * workFrac * (x.fte || 0), perYear = perUnit * (x.units || 0) * (x.squads || 0);
      const gateDays = x.now * ((x.gate || 0) / 100) * workFrac * (x.fte || 0);
      const tokYear = (x.tokens || 0) * 1000 / 1e6 * (x.price || 0) * (x.units || 0) * (x.squads || 0);
      out.innerHTML = kpi('Lead time change', fmt((x.base - x.now) / x.base * 100, 0), '%', fmt(x.base - x.now, 1) + ' days per unit', null, 'modelled')
        + kpi('Working days released per unit', fmt(perUnit, 1), 'dev-days', 'calendar days × 5/7 × FTE', null, 'modelled')
        + kpi('Of which gate wait', fmt(gateDays, 1), 'dev-days', 'already inside the lead time; the cost of governance', null, 'modelled')
        + kpi('Released per year', fmt(perYear, 0), 'dev-days', fmt(perYear / 220, 1) + ' engineer-years at 220 days', null, 'modelled')
        + kpi('Token spend per year', fmt(tokYear, 0), '', 'at the price entered', null, 'modelled');
    };
    box.querySelectorAll('input').forEach(i => i.addEventListener('input', calc));
    box.querySelector('#abm-' + key + '-reset').addEventListener('click', () => { F.forEach(([k]) => { box.querySelector('#abm-' + key + '-' + k).value = seed[k]; }); calc(); });
    calc();
  }

  const DEFS = [
    ['Lead time', 'lineage.md', 'Starting units late, or splitting one change into many units'],
    ['Deployment frequency', 'lineage.md release events', 'Releasing trivial units to lift the count'],
    ['Change failure rate', 'incidents.json', 'Not linking incidents to a phase'],
    ['Rework rate', 'human-decisions.md', 'Approving work that should go back'],
    ['Test first', 'evidence/index.json', 'Waiving tasks; red runs that fail for the wrong reason'],
    ['Evidence coverage', 'VERIFICATION.md (sealed)', 'Weak tests that pass; the seal stops hand edits, not weak tests'],
    ['Structured approvals', 'human-decisions.md', 'Hard to game: vague replies are refused by the guard'],
    ['Gate wait share', 'lineage.md checkpoints and decisions', 'Deciding without reading to shorten the wait'],
    ['Tokens per unit', 'runs/usage', 'Only Claude Code sessions are measured']
  ];
  function defs() { return `<details><summary>Where each number comes from, and how it can be gamed</summary><div class="tw"><table><thead><tr><th>Metric</th><th>Source file</th><th>How it gets gamed</th></tr></thead><tbody>${DEFS.map(r => `<tr><td>${esc(r[0])}</td><td class="mono">${esc(r[1])}</td><td>${esc(r[2])}</td></tr>`).join('')}</tbody></table></div><p class="note" style="margin-top:8px">Rules: every rate shows its count; a missing source shows a dash, never zero; squads are compared only with their own baseline, never ranked.</p></details>`; }

  /* ---------- entry ---------- */
  function render(root, metrics, opts = {}) {
    ensureChrome();
    root.classList.add('ab'); root.innerHTML = '';
    if (!metrics) { root.innerHTML = '<div class="ab-empty">No metrics.json yet. Run atticus metrics (or atticus bench), or let the CI job build it on every pull request.</div>'; return; }
    const squads = metrics.squads || [metrics];
    let idx = Math.min(store.get('squad', 0), squads.length - 1);
    const draw = () => {
      const m = squads[idx]; root.innerHTML = '';
      if (metrics.sample || m.sample) root.insertAdjacentHTML('beforeend', '<div class="ab-banner"><b>Sample data.</b> This page is showing a generated fixture, not a real squad.</div>');
      if (squads.length > 1) {
        root.insertAdjacentHTML('beforeend', `<div class="ab-scope"><span class="note" style="margin:0">Squad</span>${squads.map((s, i) => `<button type="button" data-i="${i}" aria-pressed="${i === idx}">${esc(s.squad)}</button>`).join('')}<span class="note" style="margin:0">Each squad is compared with its own baseline. Squads are never ranked.</span></div>`);
        root.querySelectorAll('.ab-scope button').forEach(bt => bt.addEventListener('click', () => { idx = +bt.dataset.i; store.set('squad', idx); draw(); }));
      }
      root.insertAdjacentHTML('beforeend', `<div class="ab-h"><h2>Now against baseline <span class="ab-tag measured">measured</span></h2><span class="note" style="margin:0">${esc(m.squad)} · data as of ${esc(m.as_of || '—')}</span></div><p class="ab-sub">Every figure is computed by aidlc-metrics.sh from files in the track root. A dash means the file that would produce it does not exist yet; the line under each figure names it.</p>`);
      root.insertAdjacentHTML('beforeend', kpis(m));
      root.insertAdjacentHTML('beforeend', '<div class="ab-h"><h2>Flow, governance and cost <span class="ab-tag measured">measured</span></h2></div>');
      charts(root, m, (opts.idPrefix || 'ab') + idx + '-');
      root.insertAdjacentHTML('beforeend', unitTable(m));
      if (opts.full) {
        root.insertAdjacentHTML('beforeend', '<div class="ab-h"><h2>Value model <span class="ab-tag modelled">modelled</span></h2></div><p class="ab-sub">What the measured change would be worth at your scale. Inputs start from the measured values; override any of them to test an assumption.</p>');
        valueModel(root, m, String(m.squad || idx).replace(/[^A-Za-z0-9_-]/g, '_'));
        root.insertAdjacentHTML('beforeend', '<div class="ab-h"><h2>Definitions and limits</h2></div>' + defs());
      } else {
        root.insertAdjacentHTML('beforeend', defs());
      }
    };
    draw();
    let lastW = root.clientWidth, timer;
    window.addEventListener('resize', () => { clearTimeout(timer); timer = setTimeout(() => { if (Math.abs(root.clientWidth - lastW) > 40 && root.offsetParent !== null) { lastW = root.clientWidth; draw(); } }, 150); });
  }
  window.AtticusBench = { render };
})();
