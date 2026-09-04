## Why

Before implementing any functionality, we need a clear data model and storage decision. This change captures the core data structure for the memorization system we've explored — the unified item shape, separate scheduling state, tag-based organization, and SQLite as the storage backend.

## What Changes

This change establishes the data layer for **total-recall.el**:
- **Unified item model** — a single data structure (plist-based Elisp closure) for any flashcard-like memorization target: vocabulary, technical terms, concepts, quotes, trivia, commands, formulas, etc.
- **Separate scheduling record** — SM-2 scheduling state lives in its own record, not inline on the item, for testability and separation of concerns
- **Tag-based organization** — tags are the single cross-cutting dimension; no deck hierarchy, no separate "field" concept
- **SQLite storage** — persistence via Emacs 29+'s built-in `sqlite-*` functions, with a clean adapter interface so the rest of the code never touches SQL directly
- **Storage adapter pattern** — injectable `load-item`, `save-item`, `query-due` functions, enabling future backends without changing domain code

The following are explicitly **out of scope** for this change:
- UI (review sessions, buffers, keybindings)
- Import/export
- Any user-facing commands
- Scheduling algorithm itself (SM-2) — only the data structure decisions that enable it

## Capabilities

### New Capabilities

- `item-model`: The unified item data structure — plist schema, factory function (closure-based), get/set/serialize operations, ID generation
- `tag-system`: Tag storage and basic tag operations — add, remove, and list all tags on items, query items by tag
- `scheduling`: Separate scheduling record — schema, creation, update, due-item query interface (algorithm implementation is future work)
- `storage`: SQLite persistence — table schemas, adapter functions (load, save, delete, query), database initialization, test helpers with `:memory:` databases

### Modified Capabilities

None — this is a greenfield package.

## Impact

- New files under the package root:
  - `total-recall-item.el` — item model
  - `total-recall-tags.el` — tag operations
  - `total-recall-sched.el` — scheduling record
  - `total-recall-storage.el` — SQLite adapter
- Emacs 29+ required (for `sqlite-open`, `sqlite-execute`, `sqlite-select`)
- Standard Emacs built-ins only: `json.el` for serialization, `cl-lib` for `pcase`
- The `storage.el` adapter interface defines the contract that all higher layers consume