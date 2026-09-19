## Context

The training module (`total-recall-train.el`) provides a major mode with keybindings, session state management, card rendering, and grading. The item model (`total-recall-item.el`) already supports `'set` on closures to modify fields. The storage adapter (`total-recall-storage.el`) already supports `:save-item` with upsert semantics. The capture module (`total-recall-capture.el`) has a parser (`total-recall-capture--parse`) for the `key:: value` format. See proposal.md — Why for motivation. See specs/training/spec.md — ADDED Requirements for the behavior contract.

## Goals / Non-Goals

**Goals:**
- Allow the user to edit the current item's content during a training session
- Edit only item data (term, definition, tags, depth, examples, notes, analogy)
- Preserve item identity (`:id`, `:created`), schedule state, and session progress
- Reuse the existing capture parser for the pre-fill/commit format

**Non-Goals:**
- Editing schedule parameters (interval, ease-factor, etc.)
- Deleting items from the training buffer
- Adding new optional fields to the item model
- Editing outside the training flow (dedicated browse-and-edit interface — future work)

## Decisions

### Decision: `E` keybinding over `e`

`e` is adjacent to `w` (wrong grade). A slip on `e` when intending `w` would incorrectly edit instead of grading. Using uppercase `E` (shift-e) requires a deliberate action and avoids false triggers. Kept out of the mode-map when the answer is hidden (same guard as `c`/`w`).

### Decision: Standalone edit buffer, not inline editing

A separate buffer (*total-recall-edit*) provides:
- Full control over buffer-local state (original item, adapter, return buffer)
- Familiar capture-template layout — the user sees the same format they used to create the item
- Clear commit/cancel semantics with standard `C-c C-c` / `C-c C-k` keybindings
- No risk of corrupting the read-only training buffer

### Decision: Reuse `total-recall-capture--parse` verbatim

The parser already handles `key:: value` format, continuation lines, comment stripping, and type-specific post-processing (tag→symbols, depth→integer, examples→cons cells). Reusing it avoids a second parser and guarantees format consistency between capture and edit. The only difference is that the edit flow skips schedule creation after parsing.

### Decision: Merge strategy — parsed plist over original, keeping :id and :created

```
Original serialized plist:  (:id "abc" :term "X" :definition "Y" :created "T1" :modified "T1" :tags ...)
Parsed edit plist:          (:term "X*" :definition "Y*" :tags ...)
Merged plist:               (:id "abc" :term "X*" :definition "Y*" :created "T1" :tags ...)
                             ──────────────────────────────────────────
                             → total-recall-make-item → saves via adapter
```

Fields present in the parsed plist replace original values. Fields absent from the parsed plist are dropped (the item defaults kick in via `total-recall-make-item`). `:id` and `:created` are explicitly kept from the original regardless of the parsed plist. `:modified` is auto-set by `total-recall-make-item`.

### Decision: Schedule is never touched

The edit flow only calls `:load-item` (to get the original) and `:save-item` (to persist edits). Schedule records are keyed by `item_id` + `direction` in a separate table with no foreign key cascade to item content — they're unaffected by item data changes.

### Decision: Re-render the training buffer from storage after commit

After saving, the training buffer re-reads the item from storage (via `:load-item`) so it displays the fresh data. The current position, direction, and session remaining list are untouched.

## Risks / Trade-offs

- [Low] **Parser is in capture module** — `total-recall-train.el` must require `total-recall-capture.el` for the parser. This is a dependency reversal concern: training gains a dependency on capture. Mitigation: the parser is a pure function with no side effects (no capture template registration, no schedule creation), so the dependency is lightweight and testable. A future refactor could extract the parser into a shared module, but that's not justified yet.
- [Low] **Edit buffer uses auto-generated keymap with C-c C-c / C-c C-k** — these are Emacs conventions for "commit/kill current action." They interfere with any global binding, but only while the edit buffer is active.

## Open Questions

*None.*