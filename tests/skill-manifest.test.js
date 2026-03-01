/**
 * Skill Manifest Tests
 * Validates all 50 skills have correct structure and metadata.
 */
'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const { parseYaml } = require('./helpers/yaml-parser');

const SDLC_ROOT = path.resolve(__dirname, '..');
const SKILLS_DIR = path.join(SDLC_ROOT, 'skills');

const VALID_CATEGORIES = [
  'development', 'planning', 'quality', 'pipeline-automation',
  'decision-support', 'spec-lifecycle', 'governance', 'production-support',
  'release', 'reporting', 'maintenance', 'knowledge-transfer', 'integration',
];

const VALID_ROLES = [
  'product-owner', 'architect', 'developer', 'qa',
  'devops-sre', 'tech-lead', 'scrum-master', 'designer',
];

const skillDirs = fs.readdirSync(SKILLS_DIR).filter(d =>
  fs.statSync(path.join(SKILLS_DIR, d)).isDirectory()
);

describe('Skill Manifest', () => {
  it('should have exactly 50 skills', () => {
    assert.strictEqual(skillDirs.length, 50, `Expected 50 skills, found ${skillDirs.length}`);
  });

  for (const skill of skillDirs) {
    describe(`skills/${skill}`, () => {
      const skillDir = path.join(SKILLS_DIR, skill);
      const yamlPath = path.join(skillDir, 'skill.yaml');
      const promptPath = path.join(skillDir, 'prompt.md');
      const legacyPath = path.join(skillDir, 'SKILL.md');

      it('has skill.yaml', () => {
        assert.ok(fs.existsSync(yamlPath), `${skill}/skill.yaml missing`);
      });

      it('has prompt.md', () => {
        assert.ok(fs.existsSync(promptPath), `${skill}/prompt.md missing`);
      });

      it('has SKILL.md (legacy)', () => {
        assert.ok(fs.existsSync(legacyPath), `${skill}/SKILL.md missing`);
      });

      it('prompt.md is non-empty', () => {
        const content = fs.readFileSync(promptPath, 'utf8');
        assert.ok(content.trim().length > 0, `${skill}/prompt.md is empty`);
      });

      it('skill.yaml has required fields', () => {
        const raw = fs.readFileSync(yamlPath, 'utf8');
        const meta = parseYaml(raw);
        assert.ok(meta.name, `${skill}: missing name`);
        assert.ok(meta.version, `${skill}: missing version`);
        assert.ok('description' in meta, `${skill}: missing description`);
        assert.ok(meta.category, `${skill}: missing category`);
        assert.ok(meta.roles, `${skill}: missing roles`);
      });

      it('name matches directory', () => {
        const raw = fs.readFileSync(yamlPath, 'utf8');
        const meta = parseYaml(raw);
        assert.strictEqual(meta.name, skill, `name "${meta.name}" does not match dir "${skill}"`);
      });

      it('version is semver', () => {
        const raw = fs.readFileSync(yamlPath, 'utf8');
        const meta = parseYaml(raw);
        const semver = /^\d+\.\d+\.\d+$/;
        assert.ok(semver.test(String(meta.version)), `version "${meta.version}" is not semver`);
      });

      it('category is valid', () => {
        const raw = fs.readFileSync(yamlPath, 'utf8');
        const meta = parseYaml(raw);
        assert.ok(
          VALID_CATEGORIES.includes(meta.category),
          `category "${meta.category}" not in ${VALID_CATEGORIES.join(', ')}`
        );
      });

      it('roles are valid', () => {
        const raw = fs.readFileSync(yamlPath, 'utf8');
        const meta = parseYaml(raw);
        const roles = Array.isArray(meta.roles) ? meta.roles : [meta.roles];
        for (const role of roles) {
          assert.ok(
            VALID_ROLES.includes(role),
            `role "${role}" not in ${VALID_ROLES.join(', ')}`
          );
        }
      });
    });
  }
});
