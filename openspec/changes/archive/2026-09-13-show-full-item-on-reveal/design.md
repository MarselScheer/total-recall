## Context

The training session renderer (`total-recall-train--render-card`) currently only displays the prompt side (term or definition) and, on reveal, the answer side. The item closure carries optional fields (`:tags`, `:depth`, `:examples`, `:notes`, `:analogy`) and schedule closures carry metadata (`:repetitions`, `:last-review`, `:lapses`). These are ignored during rendering. See proposal.md for motivation.

## Goals / Non-Goals

**Goals:**
- Show all non-nil item fields (tags, depth, examples, notes, analogy) on answer reveal
- Show schedule metadata (repetitions, last-review, lapses) for the current direction on reveal
- Render examples, notes, and analogy with distinct customizable faces
- Keep the pre-reveal display unchanged (prompt only)

**Non-Goals:**
- No change to the grading logic, queue building, or session state machine
- No change to the item or schedule data models
- No change to the capture or storage layers

## Decisions

**Decision 1: Load schedule during rendering**  
The adapter (`:load-schedule`) is already available via the session state's `:adapter` key. We load the schedule during `total-recall-train--render-card` to access `:repetitions`, `:last-review`, and `:lapses`. This adds one DB read per reveal — negligible for interactive use.

**Decision 2: Faces for colored display**  
Three new defface declarations:
- `total-recall-train-examples-face` — default: `(:inherit fixed-pitch :foreground "ForestGreen")`
- `total-recall-train-notes-face` — default: `(:inherit fixed-pitch :foreground "SaddleBrown")`
- `total-recall-train-analogy-face` — default: `(:inherit fixed-pitch :foreground "DodgerBlue")`

These are defined in `total-recall-train.el` using `defface` so users can customize them via `customize-face` or init-file.

**Decision 3: Section headings for revealed fields**  
Each field group gets a heading line (e.g., "─── Tags ───") for visual clarity, similar to the existing "─── Answer ───" heading. Nil fields are skipped entirely with no heading shown.

## Risks / Trade-offs

- [Risk] Loading the schedule on every reveal adds a DB read → Mitigation: The schedule is tiny (single row), and the interactive pace means this has no perceptible cost.
- [Risk] More revealed content could make the buffer harder to scan → Mitigation: Section headings and distinct faces provide visual structure.