# Changelog

All notable changes to SDLC Central will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-02-28

### Added
- Initial release with 50 Claude Code skills covering the full SDLC lifecycle
- Role-based installation for 8 roles: Product Owner, Architect, Developer, QA, DevOps/SRE, Tech Lead, Scrum Master, Designer
- 22 composable pipeline definitions that chain skills into role-specific workflows
- Pipeline Runner meta-skill for executing pipeline YAML definitions
- Interactive and non-interactive installation scripts
- Per-role CLAUDE.md templates with curated skill references
- Machine-readable skill catalog with role mappings (`registry/catalog.yaml`)
- Human-readable skill matrix (`registry/skill-matrix.md`)
- Quality gate and feature balance sheet default configurations
- Comprehensive documentation with role-specific guides
- npm package for `npx sdlc-central install --role developer`
- Update mechanism that preserves local config overrides
