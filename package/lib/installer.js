// ------------------------------------------------------------------
// SDLC Central — Shared Installer Logic
// ------------------------------------------------------------------
// Used by both CLI (bin/sdlc-central.js) and shell scripts.
// ------------------------------------------------------------------

const fs = require('fs');
const path = require('path');

const VERSION = '1.0.0';

const VALID_AGENTS = ['claude-code', 'cursor', 'copilot', 'windsurf', 'cline', 'aider', 'gemini', 'antigravity', 'agents-md'];

const ROLE_SKILLS = {
  'product-owner': [
    'feature-balance-sheet', 'spec-gen', 'quality-gate', 'gate-briefing',
    'scope-tracker', 'board-sync', 'report-trends', 'risk-tracker',
    'release-readiness-checker', 'release-notes', 'decision-log', 'drift-detector'
  ],
  'architect': [
    'design-review', 'plan-gen', 'quality-gate', 'decision-log',
    'tech-debt-audit', 'code-ownership-mapper', 'api-contract-analyzer',
    'report-trends', 'migration-tracker', 'impact-analysis', 'plan-merge',
    'spec-gen', 'spec-review', 'spec-evolve', 'feature-balance-sheet',
    'gate-briefing', 'reverse-engineer'
  ],
  'developer': [
    'task-gen', 'wave-scheduler', 'task-implementer', 'spec-review',
    'review-fix', 'pr-orchestrator', 'review', 'security-audit',
    'test-gen', 'dependency-update', 'tech-debt-audit', 'regression-check',
    'spec-fix', 'doc-gen', 'perf-review', 'plan-gen', 'spec-gen',
    'impact-analysis', 'onboarding-guide', 'design-review'
  ],
  'qa': [
    'spec-review', 'test-gen', 'regression-check', 'perf-review',
    'report-trends', 'release-readiness-checker', 'quality-gate',
    'security-audit', 'api-contract-analyzer', 'drift-detector'
  ],
  'devops-sre': [
    'release-readiness-checker', 'incident-detector', 'slo-sla-tracker',
    'incident-triager', 'rollback-assessor', 'approval-workflow-auditor',
    'cross-repo-standards-enforcer', 'pipeline-monitor', 'dependency-update',
    'security-audit', 'incident-postmortem-synthesizer', 'migration-tracker',
    'report-trends', 'risk-tracker'
  ],
  'scrum-master': [
    'board-sync', 'scope-tracker', 'risk-tracker', 'feedback-loop',
    'report-trends', 'pipeline-monitor', 'auto-triage', 'wave-scheduler',
    'gate-briefing'
  ],
  'designer': [
    'spec-gen', 'spec-review', 'design-review', 'api-contract-analyzer', 'doc-gen'
  ]
};

const ROLE_PIPELINES = {
  'product-owner': ['feature-intake', 'sprint-health', 'release-signoff'],
  'architect': ['design-to-plan', 'system-health', 'migration-planning'],
  'developer': ['feature-build', 'pr-workflow', 'maintenance'],
  'qa': ['test-strategy', 'regression-suite', 'release-validation'],
  'devops-sre': ['deploy-verify', 'incident-response', 'platform-health'],
  'tech-lead': ['full-pipeline', 'team-health', 'governance'],
  'scrum-master': ['sprint-tracking', 'retrospective-data', 'impediment-tracker'],
  'designer': ['spec-collaboration', 'design-validation']
};

const VALID_ROLES = Object.keys(ROLE_PIPELINES);

function mkdirp(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function copyFile(src, dest) {
  mkdirp(path.dirname(dest));
  fs.copyFileSync(src, dest);
}

// Get the appropriate directories for an agent
function getAgentDirs(projectDir, agent) {
  switch (agent) {
    case 'claude-code':
      return {
        skills: path.join(projectDir, '.claude', 'skills'),
        pipelines: path.join(projectDir, '.claude', 'pipelines'),
        config: path.join(projectDir, '.claude', 'config'),
        tracking: path.join(projectDir, '.claude', 'sdlc-central.json')
      };
    case 'cursor':
      return {
        skills: path.join(projectDir, '.cursor', 'rules'),
        pipelines: path.join(projectDir, '.cursor', 'pipelines'),
        config: path.join(projectDir, '.sdlc', 'config'),
        tracking: path.join(projectDir, '.sdlc', 'sdlc-central.json')
      };
    case 'copilot':
      return {
        skills: path.join(projectDir, '.github', 'instructions'),
        pipelines: path.join(projectDir, '.github', 'pipelines'),
        config: path.join(projectDir, '.sdlc', 'config'),
        tracking: path.join(projectDir, '.sdlc', 'sdlc-central.json')
      };
    default:
      return {
        skills: path.join(projectDir, '.sdlc', 'skills'),
        pipelines: path.join(projectDir, '.sdlc', 'pipelines'),
        config: path.join(projectDir, '.sdlc', 'config'),
        tracking: path.join(projectDir, '.sdlc', 'sdlc-central.json')
      };
  }
}

function install(sdlcRoot, projectDir, roles, agent = 'claude-code') {
  console.log('╔══════════════════════════════════════════════╗');
  console.log(`║     SDLC Central — Installing (${agent})`);
  console.log('╚══════════════════════════════════════════════╝');
  console.log('');

  if (!VALID_AGENTS.includes(agent)) {
    console.error(`Unknown agent: ${agent}`);
    console.error(`Valid agents: ${VALID_AGENTS.join(', ')}`);
    process.exit(1);
  }

  const allSkills = new Set();
  const allPipelines = {};
  const validRoles = [];

  for (const role of roles) {
    if (role === 'tech-lead' || role === 'all') {
      // Tech lead gets everything — delegate to install-all
      const { execSync } = require('child_process');
      const script = path.join(sdlcRoot, 'setup', 'install-all.sh');
      execSync(`bash "${script}" --agent ${agent}`, { stdio: 'inherit', cwd: projectDir });
      return;
    }

    if (!VALID_ROLES.includes(role)) {
      console.error(`Unknown role: ${role}`);
      console.error(`Valid roles: ${VALID_ROLES.join(', ')}`);
      process.exit(1);
    }

    validRoles.push(role);
    for (const skill of ROLE_SKILLS[role]) {
      allSkills.add(skill);
    }
    allPipelines[role] = ROLE_PIPELINES[role];
  }

  // Use adapter for skill installation
  const adapterScript = path.join(sdlcRoot, 'adapters', agent, 'adapter.sh');

  if (fs.existsSync(adapterScript)) {
    console.log(`Skills (via ${agent} adapter):`);
    const skillList = Array.from(allSkills).join(' ');
    const { execSync } = require('child_process');
    try {
      execSync(`bash "${adapterScript}" "${sdlcRoot}" "${projectDir}" ${skillList}`, { stdio: 'inherit' });
    } catch (e) {
      console.error('Adapter failed, falling back to direct copy');
    }
  } else {
    // Fallback: direct copy for claude-code
    console.log('Skills:');
    for (const skill of allSkills) {
      const src = path.join(sdlcRoot, 'skills', skill, 'SKILL.md');
      const dest = path.join(projectDir, '.claude', 'skills', skill, 'SKILL.md');
      if (fs.existsSync(src)) {
        copyFile(src, dest);
        console.log(`  ✓ ${skill}`);
      } else {
        console.log(`  ✗ ${skill} (not found)`);
      }
    }
  }

  const dirs = getAgentDirs(projectDir, agent);

  // Install pipelines (agent-agnostic YAML)
  console.log('\nPipelines:');
  for (const [role, pipelines] of Object.entries(allPipelines)) {
    for (const pipeline of pipelines) {
      const src = path.join(sdlcRoot, 'pipelines', role, `${pipeline}.pipeline.yaml`);
      const dest = path.join(dirs.pipelines, role, `${pipeline}.pipeline.yaml`);
      if (fs.existsSync(src)) {
        copyFile(src, dest);
        console.log(`  ✓ ${role}/${pipeline}`);
      }
    }
  }

  // Install config (preserve existing)
  console.log('\nConfig:');
  mkdirp(dirs.config);

  for (const configFile of ['gate-config.json', 'balance-sheet-config.json']) {
    const dest = path.join(dirs.config, configFile);
    if (!fs.existsSync(dest)) {
      const src = path.join(sdlcRoot, 'config', configFile);
      if (fs.existsSync(src)) {
        fs.copyFileSync(src, dest);
        console.log(`  ✓ ${configFile}`);
      }
    } else {
      console.log(`  ○ ${configFile} (preserved)`);
    }
  }

  // Write tracking file
  const tracking = {
    version: VERSION,
    installed_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
    source: sdlcRoot,
    agent: agent,
    roles: validRoles,
    skill_count: allSkills.size,
    pipelines_installed: true
  };
  mkdirp(path.dirname(dirs.tracking));
  fs.writeFileSync(dirs.tracking, JSON.stringify(tracking, null, 2) + '\n');

  // Create agent-specific project file if missing
  console.log('');
  if (agent === 'claude-code') {
    const claudeMd = path.join(projectDir, 'CLAUDE.md');
    if (!fs.existsSync(claudeMd)) {
      let content = '';
      const tmplDir = path.join(sdlcRoot, 'adapters', 'claude-code', 'templates');
      const baseSrc = path.join(tmplDir, 'CLAUDE.md.base');
      const fallbackBase = path.join(sdlcRoot, 'templates', 'CLAUDE.md.base');

      if (fs.existsSync(baseSrc)) {
        content = fs.readFileSync(baseSrc, 'utf8');
      } else if (fs.existsSync(fallbackBase)) {
        content = fs.readFileSync(fallbackBase, 'utf8');
      }

      for (const role of validRoles) {
        const roleSrc = path.join(tmplDir, `CLAUDE.md.${role}`);
        const fallbackRole = path.join(sdlcRoot, 'templates', `CLAUDE.md.${role}`);
        const actualSrc = fs.existsSync(roleSrc) ? roleSrc : fallbackRole;
        if (fs.existsSync(actualSrc)) {
          content += '\n' + fs.readFileSync(actualSrc, 'utf8');
        }
      }
      if (content) {
        fs.writeFileSync(claudeMd, content);
        console.log('Created CLAUDE.md with role-specific skill reference.');
      }
    } else {
      console.log('CLAUDE.md exists — preserved.');
    }
  }

  console.log('');
  console.log('════════════════════════════════════════════════');
  console.log(`  ${allSkills.size} skills installed for: ${validRoles.join(', ')} (agent: ${agent})`);
  console.log('════════════════════════════════════════════════');
}

function update(sdlcRoot, projectDir) {
  // Check both tracking locations
  let trackingPath = path.join(projectDir, '.claude', 'sdlc-central.json');
  if (!fs.existsSync(trackingPath)) {
    trackingPath = path.join(projectDir, '.sdlc', 'sdlc-central.json');
  }

  if (!fs.existsSync(trackingPath)) {
    console.error('SDLC Central not installed. Run "sdlc-central install" first.');
    process.exit(1);
  }

  const tracking = JSON.parse(fs.readFileSync(trackingPath, 'utf8'));
  const agent = tracking.agent || 'claude-code';

  console.log(`Updating from v${tracking.version} to v${VERSION}...`);
  console.log(`Roles: ${tracking.roles.join(', ')}`);
  console.log(`Agent: ${agent}`);

  if (tracking.roles.includes('all')) {
    const { execSync } = require('child_process');
    const script = path.join(sdlcRoot, 'setup', 'install-all.sh');
    execSync(`bash "${script}" --agent ${agent}`, { stdio: 'inherit', cwd: projectDir });
  } else {
    install(sdlcRoot, projectDir, tracking.roles, agent);
  }
}

function list(sdlcRoot) {
  console.log('SDLC Central — Available Skills & Pipelines\n');

  // Load catalog
  const catalogPath = path.join(sdlcRoot, 'registry', 'catalog.yaml');
  if (fs.existsSync(catalogPath)) {
    console.log('Roles:');
    for (const role of VALID_ROLES) {
      const skills = ROLE_SKILLS[role] || [];
      const pipelines = ROLE_PIPELINES[role] || [];
      const skillCount = role === 'tech-lead' ? 50 : skills.length;
      console.log(`  ${role.padEnd(16)} ${String(skillCount).padStart(2)} skills, ${pipelines.length} pipelines`);
    }
  }

  console.log('\nSkills:');
  const skillsDir = path.join(sdlcRoot, 'skills');
  if (fs.existsSync(skillsDir)) {
    const skills = fs.readdirSync(skillsDir).filter(d =>
      fs.existsSync(path.join(skillsDir, d, 'SKILL.md')) ||
      fs.existsSync(path.join(skillsDir, d, 'skill.yaml'))
    ).sort();
    for (const skill of skills) {
      console.log(`  /${skill}`);
    }
    console.log(`\n  Total: ${skills.length} skills`);
  }

  console.log('\nPipelines:');
  const pipelinesDir = path.join(sdlcRoot, 'pipelines');
  if (fs.existsSync(pipelinesDir)) {
    const roles = fs.readdirSync(pipelinesDir).filter(d =>
      d !== '_engine' && d !== 'README.md' &&
      fs.statSync(path.join(pipelinesDir, d)).isDirectory()
    ).sort();
    for (const role of roles) {
      const pipelines = fs.readdirSync(path.join(pipelinesDir, role))
        .filter(f => f.endsWith('.pipeline.yaml'))
        .map(f => f.replace('.pipeline.yaml', ''));
      for (const p of pipelines) {
        console.log(`  ${role}/${p}`);
      }
    }
  }

  console.log('\nAgents:');
  console.log('  claude-code, cursor, copilot, windsurf, cline, aider, gemini, antigravity, agents-md');
}

module.exports = { install, update, uninstall: () => {}, list };
