#!/usr/bin/env node
// ------------------------------------------------------------------
// SDLC Central CLI — Entry Point
// ------------------------------------------------------------------
// Commands:
//   sdlc-central install [--role <role>] [--agent <agent>]
//   sdlc-central update
//   sdlc-central list
//   sdlc-central uninstall
// ------------------------------------------------------------------

const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');
const { install, update, uninstall, list } = require('../lib/installer');

const args = process.argv.slice(2);
const command = args[0];

const SDLC_ROOT = path.resolve(__dirname, '..', '..');

const VALID_AGENTS = ['claude-code', 'cursor', 'copilot', 'windsurf', 'cline', 'aider', 'gemini', 'antigravity', 'agents-md'];

function getFlag(flag) {
  const idx = args.indexOf(flag);
  if (idx !== -1 && args[idx + 1]) {
    return args[idx + 1];
  }
  return null;
}

function showHelp() {
  console.log(`
SDLC Central — Team Productivity Hub

Usage:
  sdlc-central install                           Interactive role + agent selection
  sdlc-central install --role <r> [--agent <a>]  Install for a specific role and agent
  sdlc-central update                            Update skills + pipelines
  sdlc-central list                              List available skills and pipelines
  sdlc-central uninstall                         Remove SDLC Central from project

Roles:
  product-owner, architect, developer, qa,
  devops-sre, tech-lead, scrum-master, designer

Agents:
  claude-code (default), cursor, copilot, windsurf, cline, aider, gemini, antigravity, agents-md

Examples:
  npx sdlc-central install --role developer
  npx sdlc-central install --role developer --agent cursor
  npx sdlc-central install --role qa --agent copilot
  npx sdlc-central list
  npx sdlc-central update
`);
}

switch (command) {
  case 'install': {
    const agent = getFlag('--agent') || 'claude-code';

    if (!VALID_AGENTS.includes(agent)) {
      console.error(`Unknown agent: ${agent}`);
      console.error(`Valid agents: ${VALID_AGENTS.join(', ')}`);
      process.exit(1);
    }

    const roleIndex = args.indexOf('--role');
    if (roleIndex !== -1 && args[roleIndex + 1]) {
      // Collect all --role arguments
      const roles = [];
      for (let i = 1; i < args.length; i++) {
        if (args[i] === '--role' && args[i + 1]) {
          roles.push(args[i + 1]);
          i++;
        }
      }
      install(SDLC_ROOT, process.cwd(), roles, agent);
    } else {
      // Interactive mode — delegate to shell script
      const script = path.join(SDLC_ROOT, 'setup', 'install.sh');
      try {
        execSync(`bash "${script}"`, { stdio: 'inherit', cwd: process.cwd() });
      } catch (e) {
        process.exit(e.status || 1);
      }
    }
    break;
  }

  case 'update': {
    update(SDLC_ROOT, process.cwd());
    break;
  }

  case 'list': {
    list(SDLC_ROOT);
    break;
  }

  case 'uninstall': {
    const script = path.join(SDLC_ROOT, 'setup', 'uninstall.sh');
    try {
      execSync(`bash "${script}"`, { stdio: 'inherit', cwd: process.cwd() });
    } catch (e) {
      process.exit(e.status || 1);
    }
    break;
  }

  case '--help':
  case '-h':
  case undefined:
    showHelp();
    break;

  default:
    console.error(`Unknown command: ${command}`);
    showHelp();
    process.exit(1);
}
