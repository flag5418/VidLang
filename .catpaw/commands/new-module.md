# new-module

Create a new feature module following VidLang conventions.

Workflow:
1. Create model in lib/models/ (extends BaseEntity)
2. Register entity in lib/main.dart DatabaseService
3. Create service in lib/services/
4. Create module provider (if module-private) or global provider
5. Create page directory in lib/views/{module}/
6. Write {module}_page.dart (< 800 lines)
7. Extract widgets/ subdirectory for child components
8. Update docs/ and knowledge base

Reference: AGENTS.md Section 7.1 for the complete checklist.
