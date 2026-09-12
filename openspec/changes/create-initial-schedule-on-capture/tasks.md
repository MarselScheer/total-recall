## 1. Capture commit creates initial schedules

- [x] 1.1 Modify `total-recall-capture--commit` to create both `"forward"` and `"backward"` schedule entries for a newly captured item after saving it, using `total-recall-make-schedule` with default values (next-review = now). Verify by running all existing capture tests — they must pass with the unchanged assertions.
- [x] 1.2 Update `test-capture-commit-saves-item` to also assert that forward and backward schedule entries exist for the committed item, and that their `:next-review` is a non-nil ISO-8601 timestamp. Run the test to confirm.

## 2. Verify existing items

Per the design risk/acceptance: items captured before this change remain invisible to training — users must backfill manually or re-capture them. No backfill helper is needed.