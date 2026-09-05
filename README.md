# Total Recall — OpenSpec Learning Project

> **This repository is primarily a sandbox for learning and experimenting with
> [OpenSpec](https://github.com/fission-ai/openspec)**, a spec-driven
> development workflow. The actual project (a spaced-repetition memorization
> tool in Emacs Lisp) is the vehicle for that learning — not the end goal.

---

## What is this project?

**Total Recall** is a flashcard / spaced-repetition memorization system written
in Emacs Lisp. It lets you create items (a term + definition, with tags and a
review depth), schedule them for review, and persist everything to a SQLite
database — all inside Emacs.

The project is organized as a set of small, independently testable modules
following a closure-based, dependency-injected design:

| Module | File | Purpose |
|---|---|---|
| **Item Model** | `total-recall-item.el` | Unified item data structure as a closure over a plist |
| **Scheduling** | `total-recall-sched.el` | Spaced-repetition scheduling algorithm |
| **Storage** | `total-recall-storage.el` | SQLite persistence layer (adapter pattern) |
| **Tags** | `total-recall-tags.el` | Tag-based filtering and organization |

## Why OpenSpec?

The `openspec/` directory contains the real experiment:

- **`openspec/specs/`** — Machine-readable specifications for each module,
  written in a structured Gherkin-like format. These specs define the contract
  before any code is written.
- **`openspec/changes/`** — Change proposals that describe what needs to be
  built, why, and how. Completed changes go to `archive/`.
- **`openspec/config.yaml`** — Project-level OpenSpec configuration.

The workflow is: **spec → propose change → implement (AI-assisted) → verify →
archive**. This README and the code you're reading are both outputs of that
process.

## Design Principles

This project follows a set of [design rules](.eca/rules/design-principles.md) focused on
testability, dependency injection, closure-based composition, and avoiding
CLOS/classes. Every function is designed to be tested in isolation without
mockist trickery.

## Running Tests

```bash
mise run test
```

This runs the ERT test suite in batch Emacs. All modules have their own test
file under `tests/`:

- `tests/test-item-model.el`
- `tests/test-sched-model.el`
- `tests/test-storage.el`
- `tests/test-tags.el`
- `tests/test-integration.el`

## Status

This is very much a **work in progress** — the project exists to explore
OpenSpec's spec-driven workflow, teach its patterns, and discover what works
and what doesn't. Expect rough edges, half-finished features, and the
occasional design pivot.