/**
 * Adapter Output Tests
 * Runs each of the 9 adapters with 3 test skills and validates output.
 */
'use strict';

const { describe, it, before, after } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const { execSync } = require('node:child_process');
const os = require('node:os');

const SDLC_ROOT = path.resolve(__dirname, '..');

// Test with 3 skills: small (review), medium (spec-gen), large (board-sync)
const TEST_SKILLS = ['review', 'spec-gen', 'board-sync'];
const MAX_WINDSURF_CHARS = 6000;

const AGENTS = [
  {
    name: 'claude-code',
    outputDir: '.claude/skills',
    filePattern: (skill) => `${skill}/SKILL.md`,
  },
  {
    name: 'cursor',
    outputDir: '.cursor/rules',
    filePattern: (skill) => `sdlc-${skill}.mdc`,
  },
  {
    name: 'copilot',
    outputDir: '.github/instructions',
    filePattern: (skill) => `sdlc-${skill}.instructions.md`,
  },
  {
    name: 'windsurf',
    outputDir: '.windsurf/rules',
    filePattern: (skill) => `sdlc-${skill}.md`,
  },
  {
    name: 'cline',
    outputDir: '.clinerules',
    filePattern: (skill) => `sdlc-${skill}.md`,
  },
  {
    name: 'aider',
    outputDir: '.sdlc/skills',
    filePattern: (skill) => `${skill}.md`,
    extraCheck: (projectDir) => {
      // Aider also creates CONVENTIONS.md
      return fs.existsSync(path.join(projectDir, 'CONVENTIONS.md'));
    },
  },
  {
    name: 'gemini',
    outputDir: null, // GEMINI.md at root
    filePattern: () => null,
    singleFile: 'GEMINI.md',
  },
  {
    name: 'antigravity',
    outputDir: '.antigravity/rules',
    filePattern: (skill) => `sdlc-${skill}.md`,
  },
  {
    name: 'agents-md',
    outputDir: null, // AGENTS.md at root
    filePattern: () => null,
    singleFile: 'AGENTS.md',
  },
];

describe('Adapter Output', () => {
  for (const agent of AGENTS) {
    describe(`${agent.name} adapter`, () => {
      let projectDir;

      before(() => {
        // Create a temp directory for this adapter's output
        projectDir = fs.mkdtempSync(path.join(os.tmpdir(), `sdlc-test-${agent.name}-`));
      });

      after(() => {
        // Clean up
        fs.rmSync(projectDir, { recursive: true, force: true });
      });

      it('runs without error', () => {
        const adapterPath = path.join(SDLC_ROOT, 'adapters', agent.name, 'adapter.sh');
        const cmd = `bash "${adapterPath}" "${SDLC_ROOT}" "${projectDir}" ${TEST_SKILLS.join(' ')}`;
        try {
          execSync(cmd, { stdio: 'pipe', timeout: 30000 });
        } catch (err) {
          assert.fail(`Adapter ${agent.name} failed: ${err.stderr?.toString() || err.message}`);
        }
      });

      if (agent.singleFile) {
        // Agents that produce a single file (gemini, agents-md)
        it(`produces ${agent.singleFile}`, () => {
          const adapterPath = path.join(SDLC_ROOT, 'adapters', agent.name, 'adapter.sh');
          execSync(`bash "${adapterPath}" "${SDLC_ROOT}" "${projectDir}" ${TEST_SKILLS.join(' ')}`, {
            stdio: 'pipe', timeout: 30000,
          });
          const filePath = path.join(projectDir, agent.singleFile);
          assert.ok(
            fs.existsSync(filePath),
            `Expected ${agent.singleFile} at ${filePath}`
          );
          const content = fs.readFileSync(filePath, 'utf8');
          assert.ok(content.length > 0, `${agent.singleFile} is empty`);
          // All test skills should be mentioned
          for (const skill of TEST_SKILLS) {
            assert.ok(
              content.includes(skill),
              `${agent.singleFile} does not mention skill "${skill}"`
            );
          }
        });
      } else {
        // Agents that produce per-skill files
        for (const skill of TEST_SKILLS) {
          it(`produces output for ${skill}`, () => {
            const adapterPath = path.join(SDLC_ROOT, 'adapters', agent.name, 'adapter.sh');
            execSync(`bash "${adapterPath}" "${SDLC_ROOT}" "${projectDir}" ${TEST_SKILLS.join(' ')}`, {
              stdio: 'pipe', timeout: 30000,
            });
            const filePath = path.join(projectDir, agent.outputDir, agent.filePattern(skill));
            assert.ok(
              fs.existsSync(filePath),
              `Expected output at ${filePath}`
            );
            const content = fs.readFileSync(filePath, 'utf8');
            assert.ok(content.length > 0, `Output for ${skill} is empty`);
          });
        }
      }

      // Windsurf-specific: no file exceeds 6000 chars
      if (agent.name === 'windsurf') {
        it('no file exceeds 6000 characters', () => {
          const adapterPath = path.join(SDLC_ROOT, 'adapters', agent.name, 'adapter.sh');
          execSync(`bash "${adapterPath}" "${SDLC_ROOT}" "${projectDir}" ${TEST_SKILLS.join(' ')}`, {
            stdio: 'pipe', timeout: 30000,
          });
          const rulesDir = path.join(projectDir, '.windsurf', 'rules');
          if (fs.existsSync(rulesDir)) {
            const files = fs.readdirSync(rulesDir);
            for (const file of files) {
              const filePath = path.join(rulesDir, file);
              const content = fs.readFileSync(filePath, 'utf8');
              assert.ok(
                content.length <= MAX_WINDSURF_CHARS,
                `${file}: ${content.length} chars exceeds ${MAX_WINDSURF_CHARS} limit`
              );
            }
          }
        });

        it('condensed files are valid markdown', () => {
          const adapterPath = path.join(SDLC_ROOT, 'adapters', agent.name, 'adapter.sh');
          execSync(`bash "${adapterPath}" "${SDLC_ROOT}" "${projectDir}" ${TEST_SKILLS.join(' ')}`, {
            stdio: 'pipe', timeout: 30000,
          });
          const rulesDir = path.join(projectDir, '.windsurf', 'rules');
          if (fs.existsSync(rulesDir)) {
            const files = fs.readdirSync(rulesDir);
            for (const file of files) {
              const filePath = path.join(rulesDir, file);
              const content = fs.readFileSync(filePath, 'utf8');
              // Should start with a heading or YAML frontmatter
              assert.ok(
                content.startsWith('#') || content.startsWith('---'),
                `${file}: does not start with markdown heading or frontmatter`
              );
              // Should not end mid-word (no truncation artifacts)
              const lastLine = content.trim().split('\n').pop();
              assert.ok(
                lastLine.length > 0,
                `${file}: ends with empty line`
              );
            }
          }
        });

        it('stores full versions in .sdlc/skills/', () => {
          const adapterPath = path.join(SDLC_ROOT, 'adapters', agent.name, 'adapter.sh');
          execSync(`bash "${adapterPath}" "${SDLC_ROOT}" "${projectDir}" ${TEST_SKILLS.join(' ')}`, {
            stdio: 'pipe', timeout: 30000,
          });
          for (const skill of TEST_SKILLS) {
            const fullPath = path.join(projectDir, '.sdlc', 'skills', `${skill}.md`);
            assert.ok(
              fs.existsSync(fullPath),
              `Full version missing: .sdlc/skills/${skill}.md`
            );
            // Full version should be the complete prompt.md content
            const fullContent = fs.readFileSync(fullPath, 'utf8');
            const originalPrompt = fs.readFileSync(
              path.join(SDLC_ROOT, 'skills', skill, 'prompt.md'), 'utf8'
            );
            assert.ok(
              fullContent.includes(originalPrompt.slice(0, 100)),
              `Full version of ${skill} does not contain original prompt content`
            );
          }
        });
      }

      // Aider-specific: check CONVENTIONS.md
      if (agent.extraCheck) {
        it('produces extra output files', () => {
          const adapterPath = path.join(SDLC_ROOT, 'adapters', agent.name, 'adapter.sh');
          execSync(`bash "${adapterPath}" "${SDLC_ROOT}" "${projectDir}" ${TEST_SKILLS.join(' ')}`, {
            stdio: 'pipe', timeout: 30000,
          });
          assert.ok(
            agent.extraCheck(projectDir),
            `Extra output check failed for ${agent.name}`
          );
        });
      }
    });
  }
});
