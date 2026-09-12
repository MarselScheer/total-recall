## Why

The system captures memorization items but provides no way to review or train them. Users need an interactive training session to reinforce recall through spaced repetition — the core purpose of a flashcard system.

## What Changes

- **New module**: `total-recall-train.el` — interactive training buffer, session queue, and grading loop
- **Dual-track scheduling**: Schedule records gain a `:direction` field (`forward` / `backward`), so term→definition and definition→term recall are tracked independently with separate SM-2 intervals
- **SM-2 grading function**: Pure function in `total-recall-sched.el` that takes a binary grade (correct/wrong) and produces updated schedule state
- **Storage schema change**: `schedule` table adds a `direction` column; PK becomes `(item_id, direction)` — **BREAKING** for existing schedule data
- **Direction-aware queries**: `:query-due` accepts a direction parameter; `:load-schedule` and `:save-schedule` become direction-sensitive
- **Tag filtering**: Training session optionally filters by a single tag (leveraging existing `:query-by-tag`)
- **"Both" direction mode**: When both directions are selected, each item produces two independent queue entries (forward + backward), each with their own schedule track
- **Binary grading**: User marks each card as correct or wrong. Correct → SM-2 quality 5; Wrong → SM-2 quality 0 (interval reset, lapse +1)

## Capabilities

### New Capabilities
- `training`: Interactive training session buffer, queue building, grading flow, keybindings

### Modified Capabilities
- `scheduling`: Schedule records gain `:direction` field and binary SM-2 grading function
- `storage`: Schedule table adds `direction` column; direction-aware load/save/query operations

## Impact

| File | Impact |
|---|---|
| `total-recall-sched.el` | Add `:direction` field to schedule data model; add `total-recall-sched--sm2-grade` pure function |
| `total-recall-storage.el` | Add `direction` column to `schedule` table; update `:load-schedule`, `:save-schedule`; implement `:query-due` with direction parameter |
| `total-recall-train.el` | **New file** — entry point `total-recall-train`, interactive buffer mode, queue builder, session loop |
| `total-recall.el` (main) | Add autoloads for training entry point |
| Tests | Schedule tests, storage tests need dual-track updates; new test files for training |