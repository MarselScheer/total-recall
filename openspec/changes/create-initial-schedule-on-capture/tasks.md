## 1. Capture commit creates initial schedules

- [ ] 1.1 Modify `total-recall-capture--commit` to create both `"forward"` and `"backward"` schedule entries for a newly captured item after saving it, using `total-recall-make-schedule` with default values (next-review = now). Verify by running all existing capture tests — they must pass with the unchanged assertions.
- [ ] 1.2 Update `test-capture-commit-saves-item` to also assert that forward and backward schedule entries exist for the committed item, and that their `:next-review` is a non-nil ISO-8601 timestamp. Run the test to confirm.

## 2. Verify existing items

- [ ] 2.1 Provide a SQL snippet or a helper command (`total-recall-storage-backfill-schedules`) to create initial schedule entries for existing items that lack them. The user can run it against their database to make the items they added 2 hours ago appear in training.