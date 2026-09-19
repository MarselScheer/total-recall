# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.0] — 2026-09-19

### Added

- **Edit module** (`total-recall-edit.el`) — interactive editing of
  memorization items via a dedicated edit buffer. Users can modify term,
  definition, tags, depth, examples, notes, and analogy fields using the same
  `key:: value` format as the capture template. Commit (`C-c C-c`) persists
  changes, cancel (`C-c C-k`) discards them.
- **Training edit keybinding** — `E` (uppercase) in the training buffer opens
  the edit buffer when the answer is revealed. After committing, the training
  display updates with the new values while preserving card position and
  session progress.
- **Storage update support** — `total-recall-storage-init`'s `:save-item`
  adapter now uses `INSERT OR IGNORE` + `UPDATE` instead of `INSERT OR
  REPLACE`, preventing accidental deletion of schedule records (foreign key
  targets).
- **Tests** — 18 new ERT tests in `tests/test-edit.el` covering pre-fill,
  commit, cancel, validation, and after-commit callback; 4 new tests in
  `tests/test-train.el` for edit keybinding and display update.

### Changed

- `total-recall-storage.el` — `:save-item` split into INSERT and UPDATE
  operations for safer item editing.
- `total-recall-train.el` — `total-recall-train--render-card` now reloads the
  item from storage on every render to reflect edits made via the edit buffer.
- `total-recall-train.el` — added `E` keybinding in
  `total-recall-train-mode-map` and updated help text.
- `total-recall.el` — added `(require 'total-recall-edit)` for the new module.

### Documentation

- **OpenSpec specs** — added 8 edit scenarios to
  `openspec/specs/training/spec.md`; added scenario IDs to capture spec
  scenarios.

## [0.4.1] — 2026-09-13

### Added

- **Unquoted example support** — `total-recall-capture--parse-examples` now
  handles bare/unquoted bullet text (e.g. `- просто текст`) by treating it as a
  plain example with no properties. Previously, unquoted bullets were silently
  skipped and never persisted, making the examples field non-functional for the
  most intuitive input format.
- **Tests** — 2 new ERT tests covering unquoted examples and mixed
  quoted/unquoted bullet parsing.

### Changed

- `total-recall-capture--parse-examples` — added a third parse branch for
  unquoted bullet lines, falling through to treat bare text as a plain example
  when no opening quote is detected.

## [0.4.0] — 2026-09-13

### Added

- **Full item reveal** — when the answer is revealed during a training session,
  schedule metadata (repetitions, last-review, lapses) is now displayed alongside
  the answer for the current direction.
- **Item field display on reveal** — non-nil item fields (tags, depth, examples,
  notes, analogy) are shown on answer reveal, with each field heading on its
  own line and colored faces for rich fields.
- **Custom faces** — three new faces for revealed fields:
  - `total-recall-train-examples-face` (ForestGreen, fixed-pitch) — for `:examples`
  - `total-recall-train-notes-face` (SaddleBrown, fixed-pitch) — for `:notes`
  - `total-recall-train-analogy-face` (DodgerBlue, fixed-pitch) — for `:analogy`
- **Rendering helper** (`total-recall-train--render-field`) — reusable function
  that inserts a heading with `─── ───` delimiters and optionally applies a
  face to the value text; skips nil values gracefully.
- **Tests** — 8 new ERT tests covering schedule metadata display, all-item-field
  reveal, nil-field omission, face definitions, and the render-field helper.

### Changed

- `total-recall-train--render` — enhanced the answer-revealed branch to show
  schedule metadata from the direction-aware schedule and all non-nil item
  fields with appropriate faces.

## [0.3.1] — 2026-09-12

### Fixed

- **Initial schedule creation on capture** — `total-recall-capture--commit` now creates
  `"forward"` and `"backward"` schedule entries for newly captured items, making them
  immediately due for review. Previously, items captured via org-capture were persisted
  to the `items` table but never received a `schedule` row, rendering them invisible
  to the training queue.

## [0.3.0] — 2026-09-12

### Added

- **Training module** (`total-recall-train.el`) — interactive review sessions
  with card display, answer reveal, and binary grading (correct/wrong).
- **Dual-track scheduling** — schedule records now carry a `direction` field
  (`forward` / `backward`), enabling independent spaced-repetition tracking
  for term→definition and definition→term recall.
- **SM-2 binary grading** (`total-recall-sched--sm2-grade`) — pure SM-2
  function mapping correct→quality 5 (advances interval) and wrong→quality 0
  (resets interval, increments lapses). Ease-factor follows the standard SM-2
  formula with 1.3 floor.
- **"Both" direction mode** — each due item appears twice (forward + backward)
  in the session queue, with independent schedule tracks.
- **Tag filtering** — optional single-tag filter at session start via
  `completing-read`.
- **Wrong-card re-queueing** — cards graded wrong are placed back at the end
  of the queue and reappear before the session ends.
- **Queue shuffling** — session queue is randomly shuffled at start for
  variety.
- **Session summary** — correct/wrong counts displayed at session end.
- **Tests** — 590-line ERT test suite for the training module under
  `tests/test-train.el`.

### Changed

- `total-recall-sched.el` — schedule data model accepts `:direction` field
  (default `"forward"`); added `total-recall-sched--sm2-grade` pure function.
- `total-recall-storage.el` — `schedule` table gains `direction` column with
  composite primary key `(item_id, direction)`; `:load-schedule` and
  `:save-schedule` are direction-aware; `:query-due` accepts a direction
  parameter.
- `total-recall.el` — added `(require 'total-recall-train)` for the new module.
- `README.md` — added training session usage documentation.
- `tests/test-sched-model.el` — updated for direction-aware schedules.
- `tests/test-storage.el` — updated for dual-track schema and
  direction-aware queries.
- `tests/test-integration.el` — minor alignment with new module layout.

### Documentation

- **OpenSpec specs** — new `openspec/specs/training/spec.md` for training
  requirements; updated `scheduling/spec.md` and `storage/spec.md` for
  dual-track and SM-2 requirements.

## [0.2.0] — 2026-09-06

### Added

- **Capture module** (`total-recall-capture.el`) — interactive capture workflow
  with template-driven item creation, configurable capture templates, item
  persistence, and inline tagging.
- **Item validation** (`total-recall-item.el`) — `total-recall-make-item` now
  validates mandatory `:term` and `:definition` keys and signals a
  `user-error` when either is missing. Regression tests added under
  `tests/test-item-model.el`.
- **Capture template safety** (`total-recall-capture.el`) — the target file is
  cleared before each capture to prevent stale content leakage; begin/end
  markers delimit the newly-inserted template region; the file is cleared
  after capture and the base buffer is marked unmodified to prevent
  overwriting cleared content on save.
- **Package entry point** (`total-recall.el`) — `require`-based entry point
  that loads all modules; package is now installable via `package.el`.
- **Tests** — ERT test suite for the capture module under `tests/test-capture.el`.
- **README** — configuration guide with `use-package` example and
  capture-template customization documentation.

### Changed

- `total-recall-storage.el` — extended to support capture module's persistence
  needs.
- `tests/test-integration.el` — updated to match new module layout.
- `mise.toml` — project tooling updated.

### Removed

- Implementation details from capture specs (moved to `total-recall-capture.el`).

## [0.1.0] — 2026-09-05

### Added

- **Item model** (`total-recall-item.el`) — closure-based item data structure
  with get/set/serialize operations and auto-generated IDs.
- **Scheduling** (`total-recall-sched.el`) — SRS scheduling algorithm with
  SM-2-like review intervals, due-date queries, and depth-based progression.
- **Storage** (`total-recall-storage.el`) — SQLite persistence via an adapter
  plist pattern (load, save, delete, query-by-tag, query-due, list-all-tags).
- **Tags** (`total-recall-tags.el`) — tag-based filtering and organization
  with union/intersection semantics.
- **Tests** — ERT test suites for all four modules plus integration tests under
  `tests/`.
- **OpenSpec specs** — structured Gherkin-like specifications for item model,
  scheduling, storage, and tag system under `openspec/specs/`.

### Changed

- Promoted all four specs from the data model change proposal to the main
  `openspec/specs/` directory (change archived).

## [0.0.1] — 2026-09-04

### Added

- Project initialization with `mise.toml` (Node.js + OpenSpec CLI).
- `design-principles.md` — design rules for Emacs Lisp (no CLOS, dependency
  injection, testability-first approach).
- OpenSpec configuration and directory scaffold.
- Initial data model change proposal for `openspec/changes/`.
