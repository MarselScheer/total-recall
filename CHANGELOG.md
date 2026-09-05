# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.1.0]: https://github.com/m/total-recall/releases/tag/v0.1.0
[0.0.1]: https://github.com/m/total-recall/releases/tag/v0.0.1