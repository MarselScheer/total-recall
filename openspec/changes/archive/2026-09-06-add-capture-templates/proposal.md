## Why

Total Recall currently has no user-facing way to add memorization items. Items can only be created programmatically via `total-recall-make-item` and saved through the storage adapter — usable in tests and scripts, but not from within Emacs interactively. This means the system can't be used as a daily memorization tool until a user can type a term and definition and have it persisted.

## What Changes

- Add a new `total-recall-capture.el` module containing the capture template system
- Register an org-capture template for Total Recall (auto-registered, but disableable)
- Create an interactive capture buffer with commented instructions for all fields
- Implement a parser that reads the buffer and converts it to an item closure
- Implement a commit function that parses, creates the item, and saves via the storage adapter
- Adapter is injected via a factory function (`total-recall-capture-init`) following the project's DI philosophy

## Capabilities

### New Capabilities
- `capture`: Org-capture based item creation — the interactive template, buffer parsing, and commit flow for adding new memorization items through a structured capture buffer.

### Modified Capabilities
- *(none — existing specs remain unchanged; item model, storage, tags, and scheduling are used as-is)*

## Impact

- **New file**: `total-recall-capture.el` — the capture module
- **New test file**: `tests/test-capture.el` — tests for parser, commit flow, and integration
- **org-mode dependency**: Required (for `org-capture`), auto-register a template entry
- **Minor schema update**: The item model's `:examples` field is confirmed as cons cells `(text . props)`, matching the existing spec — no spec change needed
- **No changes** to existing modules (item, sched, storage, tags)