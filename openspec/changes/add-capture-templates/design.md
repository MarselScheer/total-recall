## Context

The existing codebase is a set of 4 independent modules (item, scheduling, storage, tags), each using closure-based DI. There is no user-facing entry point for creating items — the only way to create one is to call `total-recall-make-item` in Lisp and save it via the storage adapter. This design adds the interactive layer on top of that foundation.

See `proposal.md — Why` for motivation; `specs/capture/spec.md` for the full behavioral contract.

## Goals / Non-Goals

**Goals:**
- Provide an interactive, org-capture-driven way to add new memorization items
- Parse the capture buffer into the existing item data model (plist → `total-recall-make-item`)
- Inject the storage adapter per the project's DI pattern
- Auto-register the org-capture template for convenience

**Non-Goals:**
- Tag completion at capture time (postponed to a later change)
- Multi-item capture (one item per capture invocation)
- Editing existing items through this system (edit is a separate concern)
- Scheduling setup during capture (schedule is created separately; see `total-recall-make-schedule`)

## Decisions

### Decision: org-capture `plain` type
The template uses type `plain` rather than `entry` or `item`. This gives us full control over the buffer content — comments, field order, whitespace — without org-mode trying to interpret or wrap the content in Org syntax. The buffer is purely a data entry form.

### Decision: Parser is a pure function
`total-recall-capture--parse` takes a string and returns a plist (or nil). It has no side effects and no dependencies. This makes it trivially testable — feed it buffer text, check the plist. No adapter, no org-capture machinery needed in tests.

### Decision: Commit is the composition root
`total-recall-capture--commit` composes the parser, item factory, tag module, and adapter. It receives the buffer string, calls parse, calls `total-recall-make-item`, applies tags via `total-recall-tag--add`, then saves via `:save-item`. This keeps the composition together and each piece independently testable.

### Decision: Factory pattern for DI
`total-recall-capture-init` is the public entry point. It receives the adapter (as returned by `total-recall-storage-init`) and returns a configured lambda that captures the full flow. This follows the same pattern as `total-recall-make-item` (factory → configured closure).

```elisp
;; Usage
(let ((adapter (total-recall-storage-init nil)))
  (total-recall-capture-init adapter))
;; Returns a lambda that, when called, runs the capture.

;; With options:
(total-recall-capture-init adapter :register nil)
;; Returns a lambda, no org-capture template registered.
```

### Decision: Auto-registration with opt-out
The factory registers an org-capture template by default (key "r", "Recall" description). An `:register nil` option suppresses this. This is friendlier than requiring manual config, and follows the Emacs convention of providing a user-facing variable to toggle.

### Decision: Line-based field format with `key:: value`
Format: `key:: value` on its own line. Continuation lines (leading whitespace) join to the previous value. This is simple to parse, easy to read, and LLM-friendly. Examples use a sub-bullet format under `examples::` with quoted strings for the text part.

Example buffer body:
```
term:: dependency injection
definition:: passing dependencies as function arguments
tags:: :software :design-patterns
depth:: 4
examples::
  - "In Python: injection via args" :lang "Python"
  - "In Java: constructor injection" :lang "Java"
```

Comments are `;;`-prefixed lines, stripped entirely before parsing.

### Decision: Example cons cell format from buffer
Example bullets parse as `("text" . (:key "val" ...))`. The text is the double-quoted string; remaining tokens on the line are alternating keyword/value pairs forming the props plist. Multi-line example text is supported via embedded newlines within the quoted string (continuation lines within examples indent further).

## Risks / Trade-offs

| Risk | Mitigation |
|---|---|
| **org-capture version compatibility** — different Emacs versions handle `:before-finalize` hooks slightly differently | Test on the project's minimum supported Emacs; use `condition-case` in the hook |
| **Large example blocks slow down the buffer** — code snippets with many lines could make the capture buffer feel sluggish | Pure text buffer, no font-lock issues; performance is negligible |
| **Accidental save on empty buffer** — user opens capture, changes mind, hits C-c C-c | Parser returns nil for empty/comment-only buffers; commit signals error, capture aborts |
| **org-capture template name collision** — user might already have "r" bound | Document how to rebind; `:register nil` + manual config snippet in docstring |