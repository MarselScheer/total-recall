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
| **Training** | `total-recall-train.el` | Interactive review sessions with card display and binary grading |

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

## Installation

### Prerequisites

- Emacs 26.1 or later
- [straight.el](https://github.com/radian-software/straight.el) bootstrap (if not already set up)

### Via straight.el + use-package

Add the following to your Emacs config:

```elisp
(use-package total-recall
  :straight (total-recall :type git :host github
                          :repo "MarselScheer/total-recall"
                          :branch "main"))
```

### Local development checkout

Use the `:local-repo` keyword to point straight.el at an
existing clone on disk. This is useful when you're actively developing the
package and want to avoid re-cloning.

```elisp
;; Clone the repo somewhere, e.g. /home/user/code/total-recall
;; Then tell straight.el about it:
(use-package total-recall
  :straight (total-recall :type git :host github :repo "MarselScheer/total-recall"
                          :local-repo "/home/user/code/total-recall"))
```

## Configuration

The package does **not** auto-configure on load — you must explicitly
initialize a storage adapter and pass it to the capture system. This follows
the project's dependency-injection design: you decide where data lives and
whether to register the org-capture template.

### 1. Initialize a storage adapter

`total-recall-storage-init` creates a SQLite-backed adapter.  Pass `nil` for
an in-memory database (volatile — useful for testing or ephemeral sessions),
or a file path for persistent storage:

```elisp
;; In-memory (data lost on restart)
(setq recall-adapter (total-recall-storage-init nil))

;; File-backed persistence (recommended)
(setq recall-adapter (total-recall-storage-init "~/.emacs.d/recall.db"))
```

The returned adapter is a plist of functions (`:load-item`, `:save-item`,
`:delete-item`, etc.) that the capture module uses under the hood.

### 2. Wire up the capture template

`total-recall-capture-init` takes the adapter and returns a configured capture
function.  By default (`:register t`), it registers an org-capture template
with key `"r"` / description `"Recall"`.  Pass `:register nil` to skip this:

```elisp
;; Register the "Recall" capture template (default)
(total-recall-capture-init recall-adapter)

;; Or: skip automatic registration (e.g., you want to add it manually)
(total-recall-capture-init recall-adapter :register nil)
```

### Full example with `use-package`

Putting it all together in a `:config` block:

```elisp
(use-package total-recall
  :straight (total-recall :type git :host github :repo "MarselScheer/total-recall"
                          :local-repo "/home/m/docker_fs/repos/total-recall")
  :config
  (let* ((recall-db "~/.emacs.d/recall.db")
         (adapter (total-recall-storage-init recall-db)))
    ;; Register the "Recall" org-capture template
    (total-recall-capture-init adapter)
    ;; Point the training session at the same database
    (setq total-recall-train-db-path recall-db)))
```

After loading, run `M-x org-capture` (or your org-capture keybinding) and
select **"Recall"** (key `"r"`) to open the structured capture buffer.

### Removing the capture template after loading

When `total-recall-capture` loads with its default `:register` option, it adds
an `org-capture-template` with the key `"r"` ("Recall"). If you need to
unregister it (e.g., to re-register with different settings), evaluate:

```elisp
(setq org-capture-templates
      (assoc-delete-all "r" org-capture-templates))
```

This removes only the "Recall" entry that the package registered (key `"r"`),
leaving your other capture templates intact.

## Training Sessions

Once you have items with schedule entries, you can review them interactively.

### 3. Set a database path (optional)

By default, `M-x total-recall-train` uses an in-memory database. Set
`total-recall-train-db-path` to persist your data:

```elisp
;; In your config, before starting a session
(setq total-recall-train-db-path "~/.emacs.d/recall.db")
```

### 4. Start a session

```elisp
M-x total-recall-train
```

The command prompts you for:

- **Direction** — `f` (forward: term → definition), `b` (backward: definition → term),
  or `t` (both: review in both directions, independently scheduled).
- **Tag** — optional filter; press `RET` for all items. Uses `completing-read`
  against the tags present in your database.

If there are no items due, it shows a message. Otherwise, it opens a training
buffer where you:

| Key | Action |
|---|---|
| `SPC` | Reveal the answer |
| `c` | Grade correct |
| `w` | Grade wrong |
| `q` | Quit the session early |

Wrong answers are re-queued and shown again before the session ends. When the
queue is exhausted, a summary with correct/wrong counts is displayed.

Pass a prefix argument (`C-u M-x total-recall-train`) to pick a database file
at session time, overriding `total-recall-train-db-path`.

## Running Tests

```bash
mise run test
```

This runs the ERT test suite in batch Emacs. All modules have their own test
file under `tests/`.

## Status

This is very much a **work in progress** — the project exists to explore
OpenSpec's spec-driven workflow, teach its patterns, and discover what works
and what doesn't. Expect rough edges, half-finished features, and the
occasional design pivot.
