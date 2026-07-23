# VidLang Project Context for Marvis

This file provides Marvis with project-level context for the VidLang Flutter project.

## Quick Facts

- **Project**: VidLang — Flutter language learning app
- **Stack**: Flutter 3.x, Riverpod, SQLite+FTS5, tdesign_flutter, Supabase, DeepSeek
- **Architecture**: 3 engines (video + article + song)

## Authoritative Rules

The single source of truth for all project rules is `AGENTS.md` in the project root.
Please read `AGENTS.md` for complete development conventions including:
- Directory structure and file placement
- Naming conventions
- Code standards (models, state management, theme)
- Component architecture
- Development workflow

## Key Docs

| Doc | Path |
|-----|------|
| AI Collaboration Spec | `AGENTS.md` |
| Architecture Overview | `docs/architecture/overview-V1.1.md` |
| Database Schema | `docs/architecture/database-schema-V2.0.md` |
| Document Index | `docs/DOCUMENTATION_INDEX.md` |
| AI Engineering Plan | `docs/developer/ai-engineering-optimization-plan-V1.0.md` |

## AI Tool Configs

This project uses multiple AI coding tools:
- **OpenCode**: Config in `opencode.json`, skills in `.opencode/skills/`
- **CatPaw**: Commands in `.catpaw/commands/`
- **Trae**: Rules in `.trae/rules/project_rules.md`
- **Marvis**: This file (`.marvis/project-context.md`)
