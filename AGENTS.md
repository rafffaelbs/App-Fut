# AI-Friendly Refactoring & Maintenance Directives

## 1. Scope Boundary
- Restrict all operations EXCLUSIVELY to `lib/`. Do not inspect external platform folders.

## 2. AI-Optimized Codebase Architecture
To make code frictionless for AI models and humans to read and review:
- **Strong Typing over Maps:** Never query raw dynamic maps directly in UI widgets (e.g., `session!['jogadores']`). Always convert raw JSON into strongly-typed Dart data models with `factory Model.fromJson()` and `.toJson()`.
- **Single Responsibility Principle:** Keep widget files under 200 lines. Extract inline dialogs, sheets, and logic into standalone files in `lib/widgets/` or `lib/services/`.
- **Null Safety & Defensive Guards:** Replace unsafe forced unwraps (`!`) with fallbacks (`??`) or defensive guards to prevent runtime crashes.
- **Explicit Types:** Avoid vague `var` or untyped lists. Use explicit types so AI context reading is instant.

## 3. Workflow Strategy
- **Plan Mode:** Analyze bugs, JSON handling, and file bloat. Write execution steps to `implementation_plan.md`.
- **Build Mode:** Execute file edits modularly based on `implementation_plan.md`.