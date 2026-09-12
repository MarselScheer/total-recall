# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
