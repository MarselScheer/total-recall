## Context

New items captured via `total-recall-capture--commit` are persisted to the `items` table but never get a corresponding `schedule` row. The training `:query-due` adapter function JOINs `schedule` → `items` and filters by `next-review <= now`, so items without a schedule record are invisible to training.

The schedule data model (`total-recall-make-schedule`) already provides sensible defaults: interval `0.0`, ease-factor `2.5`, next-review = current time. These make a new item immediately due. The storage adapter already exposes `:save-schedule`. The only missing step is calling it from the capture commit function.

## Goals / Non-Goals

**Goals:**
- Every new item captured via `total-recall-capture--commit` gets initial schedule entries for both `"forward"` and `"backward"` directions
- The item appears in the training queue immediately after capture (for either direction or both)
- No user-facing changes to the capture template, org-capture flow, or training UI

**Non-Goals:**
- Not changing how `:query-due` works — it continues to JOIN on `schedule` as before
- Not backfilling schedule entries for existing items in the database (a separate concern; see Risks)

## Decisions

| Decision | Choice | Alternatives Considered |
|---|---|---|
| Where to create schedules | In `total-recall-capture--commit`, after `:save-item` | Could have been in `:save-item` itself, but that would couple storage logic with scheduling policy. Could have been in a post-capture hook, but that adds indirection for no benefit. Commit is the natural composition root. |
| Both directions vs. only forward | Create both `"forward"` and `"backward"` | Only forward would mean items are invisible when the user trains in "backward" or "both" mode until they've been graded at least once in forward. Creating both is more consistent with the dual-track scheduling model and costs one extra SQL INSERT. |
| Default next-review | Current timestamp (now) | Using the current time means the item is due immediately. An alternative would be to set next-review slightly in the past (e.g., 1 second ago) to guarantee the comparison in `:query-due` works, but using `now` is safe because `<=` covers the boundary. |

## Risks / Trade-offs

- **Existing items without schedules** — Items captured before this change remain invisible to training. Users must backfill manually or re-capture them. This is acceptable for an early-stage system where the database is ephemeral or can be reseeded. A future change could add a `total-recall-storage-backfill-schedules` command.
- **No migration script** — No schema change, so no migration needed. The change is purely additive.

## Open Questions

None.