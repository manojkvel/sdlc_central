/**
 * Installer Consistency Tests
 * Validates that install scripts reference existing skills, pipelines, and adapters.
 */
'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const SDLC_ROOT = path.resolve(__dirname, '..');
const SKILLS_DIR = path.join(SDLC_ROOT, 'skills');
const PIPELINES_DIR = path.join(SDLC_ROOT, 'pipelines');
const ADAPTERS_DIR = path.join(SDLC_ROOT, 'adapters');

const skillDirs = new Set(
  fs.readdirSync(SKILLS_DIR).filter(d =>
    fs.statSync(path.join(SKILLS_DIR, d)).isDirectory()
  )
);

const VALID_AGENTS = [
  'claude-code', 'cursor', 'copilot', 'windsurf', 'cline',
  'aider', 'gemini', 'antigravity', 'agents-md',
];

// Parse ROLE_SKILLS from install-role.sh
function extractRoleSkills(scriptPath) {
  const content = fs.readFileSync(scriptPath, 'utf8');
  const roles = {};
  // Match: role)\n    SKILLS=(skill1 skill2 ...)\n    PIPELINES=(p1 p2 ...)
  const caseRegex = /^\s+([\w-]+)\)\s*\n\s+SKILLS=\(([^)]+)\)\s*\n\s+PIPELINES=\(([^)]+)\)/gm;
  let match;
  while ((match = caseRegex.exec(content)) !== null) {
    const role = match[1];
    if (role === '*') continue;
    roles[role] = {
      skills: match[2].trim().split(/\s+/),
      pipelines: match[3].trim().split(/\s+/),
    };
  }
  return roles;
}

// Parse SKILLS array from install-all.sh
function extractAllSkills(scriptPath) {
  const content = fs.readFileSync(scriptPath, 'utf8');
  const match = content.match(/SKILLS=\(\s*([\s\S]*?)\s*\)/);
  if (!match) return [];
  return match[1].trim().split(/\s+/).filter(s => s && !s.startsWith('#'));
}

describe('Installer Consistency', () => {
  const installRolePath = path.join(SDLC_ROOT, 'setup', 'install-role.sh');
  const installAllPath = path.join(SDLC_ROOT, 'setup', 'install-all.sh');

  describe('install-role.sh', () => {
    const roleSkills = extractRoleSkills(installRolePath);

    for (const [role, { skills, pipelines }] of Object.entries(roleSkills)) {
      describe(`role: ${role}`, () => {
        it('all skills exist in skills/ directory', () => {
          for (const skill of skills) {
            assert.ok(
              skillDirs.has(skill),
              `Role ${role} references non-existent skill "${skill}"`
            );
          }
        });

        it('all pipelines have .pipeline.yaml files', () => {
          for (const pipeline of pipelines) {
            const pipelinePath = path.join(PIPELINES_DIR, role, `${pipeline}.pipeline.yaml`);
            assert.ok(
              fs.existsSync(pipelinePath),
              `Role ${role} references non-existent pipeline "${pipeline}" (expected ${pipelinePath})`
            );
          }
        });
      });
    }
  });

  describe('install-all.sh', () => {
    const allSkills = extractAllSkills(installAllPath);

    it('lists skills', () => {
      assert.ok(allSkills.length > 0, 'No skills found in install-all.sh');
    });

    it('covers all skills in skills/ directory', () => {
      const allSet = new Set(allSkills);
      for (const skill of skillDirs) {
        assert.ok(
          allSet.has(skill),
          `Skill "${skill}" exists in skills/ but missing from install-all.sh`
        );
      }
    });

    it('every listed skill exists in skills/ directory', () => {
      for (const skill of allSkills) {
        assert.ok(
          skillDirs.has(skill),
          `install-all.sh lists "${skill}" but it does not exist in skills/`
        );
      }
    });
  });

  describe('Adapters', () => {
    for (const agent of VALID_AGENTS) {
      it(`${agent} adapter directory exists`, () => {
        const adapterDir = path.join(ADAPTERS_DIR, agent);
        assert.ok(
          fs.existsSync(adapterDir),
          `Adapter directory missing for "${agent}"`
        );
      });

      it(`${agent} has adapter.sh`, () => {
        const adapterScript = path.join(ADAPTERS_DIR, agent, 'adapter.sh');
        assert.ok(
          fs.existsSync(adapterScript),
          `${agent}/adapter.sh missing`
        );
      });
    }
  });
});
