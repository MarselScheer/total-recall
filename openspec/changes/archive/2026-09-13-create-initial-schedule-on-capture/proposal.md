## Why

New items captured via org-capture are saved to the `items` table but never get an initial schedule entry. The training queue builder (`:query-due`) only returns items that have a matching `schedule` record with `next-review <= now` — so newly captured items never appear in training. Users cannot review items they just created.

## What Changes

- **Capture flow creates initial schedules**: `total-recall-capture--commit` will create initial schedule entries for both `"forward"` and `"backward"` directions when a new item is captured
- **Initial schedule defaults**: Each new schedule uses the defaults from `total-recall-make-schedule` — interval `0.0`, ease-factor `2.5`, repetitions `0`, lapses `0`, and `next-review` set to the current timestamp (immediately due)
- **No user-facing changes**: The capture template, org-capture integration, and training UI remain unchanged

## Capabilities

### New Capabilities

*(none — no new behavior boundaries are introduced)*

### Modified Capabilities

- `capture`: The commit function SHALL create initial schedule entries for both directions when persisting a new item, so it is immediately available in training

## Impact

| File | Impact |
|---|---|
| `total-recall-capture.el` | `total-recall-capture--commit` to call `:save-schedule` for both directions after `:save-item` |
| `tests/test-capture.el` | Existing tests that verify commit behavior should be updated to also verify schedule entries exist after commit (unless over-determined) |