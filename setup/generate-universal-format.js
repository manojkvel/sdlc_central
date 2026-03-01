#!/usr/bin/env node
// ------------------------------------------------------------------
// Generate universal skill format (skill.yaml + prompt.md)
// from existing SKILL.md files + catalog.yaml
// ------------------------------------------------------------------

const fs = require('fs');
const path = require('path');

const SDLC_ROOT = path.resolve(__dirname, '..');
const SKILLS_DIR = path.join(SDLC_ROOT, 'skills');
const CATALOG_PATH = path.join(SDLC_ROOT, 'registry', 'catalog.yaml');

// Simple YAML frontmatter parser
function parseFrontmatter(content) {
  const match = content.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  if (!match) return { meta: {}, body: content };

  const meta = {};
  for (const line of match[1].split('\n')) {
    const kv = line.match(/^(\S+):\s*(.+)$/);
    if (kv) {
      let val = kv[2].trim();
      // Remove surrounding quotes
      if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
        val = val.slice(1, -1);
      }
      meta[kv[1]] = val;
    }
  }
  return { meta, body: match[2] };
}

// Parse catalog.yaml for category and roles per skill
function parseCatalog(content) {
  const skillData = {};

  // Extract skill entries from catalog
  const skillsSection = content.split(/^skills:\s*$/m)[1];
  if (!skillsSection) return skillData;

  const entries = skillsSection.split(/^\s{2}- name:\s*/m).filter(Boolean);
  for (const entry of entries) {
    const lines = entry.split('\n');
    const name = lines[0].trim();
    const data = { category: '', roles: [], argument_hint: '' };

    for (const line of lines) {
      const catMatch = line.match(/^\s+category:\s*(.+)/);
      if (catMatch) data.category = catMatch[1].trim();

      const argMatch = line.match(/^\s+argument_hint:\s*"?([^"]*)"?/);
      if (argMatch) data.argument_hint = argMatch[1].trim();

      const rolesMatch = line.match(/^\s+roles:\s*\[(.+)\]/);
      if (rolesMatch) {
        data.roles = rolesMatch[1].split(',').map(r => r.trim());
      }
    }

    skillData[name] = data;
  }

  return skillData;
}

// Make prompt content agent-agnostic
function makeAgnostic(body) {
  let result = body;

  // Replace standalone Glob: lines in code blocks with generic descriptions
  result = result.replace(/^(\s*)Glob:\s*(.+)$/gm, '$1Search for files: $2');

  // Replace standalone Grep: lines in code blocks with generic descriptions
  result = result.replace(/^(\s*)Grep:\s*(.+)$/gm, '$1Search for content: $2');

  return result;
}

// Generate skill.yaml content
function generateSkillYaml(name, frontmatter, catalogData) {
  const cat = catalogData[name] || {};
  const lines = [];
  lines.push(`name: ${name}`);
  lines.push(`version: "1.0.0"`);
  lines.push(`description: "${(frontmatter.description || cat.description || '').replace(/"/g, '\\"')}"`);
  lines.push(`category: ${cat.category || 'general'}`);

  const argHint = frontmatter['argument-hint'] || cat.argument_hint || '';
  if (argHint) {
    lines.push(`argument_hint: "${argHint.replace(/"/g, '\\"')}"`);
  }

  const roles = cat.roles || [];
  if (roles.length > 0) {
    lines.push(`roles: [${roles.join(', ')}]`);
  }

  return lines.join('\n') + '\n';
}

// Main
function main() {
  const catalog = fs.readFileSync(CATALOG_PATH, 'utf8');
  const catalogData = parseCatalog(catalog);

  const skillDirs = fs.readdirSync(SKILLS_DIR).filter(d => {
    const skillPath = path.join(SKILLS_DIR, d, 'SKILL.md');
    return fs.existsSync(skillPath);
  }).sort();

  console.log(`Processing ${skillDirs.length} skills...\n`);

  let created = 0;
  for (const skillName of skillDirs) {
    const skillMdPath = path.join(SKILLS_DIR, skillName, 'SKILL.md');
    const content = fs.readFileSync(skillMdPath, 'utf8');
    const { meta, body } = parseFrontmatter(content);

    // Generate skill.yaml
    const yamlContent = generateSkillYaml(skillName, meta, catalogData);
    const yamlPath = path.join(SKILLS_DIR, skillName, 'skill.yaml');
    fs.writeFileSync(yamlPath, yamlContent);

    // Generate prompt.md (agent-agnostic)
    const promptContent = makeAgnostic(body);
    const promptPath = path.join(SKILLS_DIR, skillName, 'prompt.md');
    fs.writeFileSync(promptPath, promptContent);

    console.log(`  ✓ ${skillName} → skill.yaml + prompt.md`);
    created += 2;
  }

  console.log(`\nDone! Created ${created} files (${created / 2} skill.yaml + ${created / 2} prompt.md)`);
}

main();
