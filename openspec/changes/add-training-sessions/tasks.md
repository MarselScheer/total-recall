## 1. Schedule — direction field and SM-2 grading (TDD: failing test, then minimal implementation, then refactor)

- [ ] 1.1 Add `:direction` field to `total-recall-make-schedule` (default `"forward"`) and update existing tests to verify the default and that `"backward"` is accepted
- [ ] 1.2 Implement `total-recall-sched--sm2-grade` as a pure function accepting quality (0 or 5) and a schedule closure, returning an updated schedule plist with SM-2 rules (quality 5 advances interval/repetitions/EF, quality 0 resets + lapses + decreases EF, ease-factor minimum 1.3, last-review/next-review timestamps)
- [ ] 1.3 Add tests for `total-recall-sched--sm2-grade` covering: correct first review sets interval 1.0 and EF increases to 2.6, correct second review sets interval 6.0, correct subsequent reviews multiply interval by ease-factor, wrong answer resets repetitions/interval/increments lapses and EF decreases to 1.7, ease-factor floor at 1.3, and last-review/next-review are updated

## 2. Storage — dual-track schedule schema and direction-aware queries (TDD: failing test, then minimal implementation, then refactor)

- [ ] 2.1 Update `total-recall-storage-init` to add `direction TEXT NOT NULL DEFAULT 'forward'` column to the `schedule` table with composite primary key `(item_id, direction)`; update existing storage tests to reflect the new column
- [ ] 2.2 Update `:load-schedule` to accept `(id direction)` and query with `WHERE item_id = ? AND direction = ?`; update tests to verify loading by direction and that wrong direction returns nil
- [ ] 2.3 Update `:save-schedule` to upsert by `(item_id, direction)` and verify forward/backward schedules for the same item coexist independently in tests
- [ ] 2.4 Implement `:query-due` to accept a direction string and return item closures whose schedule for that direction has `next-review <= current-time`; verify with tests that it returns correct results and empty list when none are due

## 3. Training session — entry point and queue builder (TDD: failing test, then minimal implementation, then refactor)

- [ ] 3.1 Create `total-recall-train.el` with the interactive command `total-recall-train` that prompts for direction (`forward`/`backward`/`both`) and optional tag (via `completing-read` against `:list-all-tags`; skip = all items)
- [ ] 3.2 Implement queue builder function that: (a) queries due items for each selected direction, (b) applies tag filter when provided, (c) deduplicates by `(item-id . direction)` pairs, (d) shuffles the queue, (e) returns a list of `(item . direction)` pairs

## 4. Training session — interactive buffer and grading loop (TDD: failing test, then minimal implementation, then refactor)

- [ ] 4.1 Define `total-recall-train-mode` major mode with keybindings: SPC (reveal answer), `c` (correct), `w` (wrong), `q` (quit session early), suppressing grading keys until answer is revealed
- [ ] 4.2 Implement card display: buffer header showing position (`"N/M"`), prompt side visible, answer side hidden; reveal key displays answer and enables grading keys
- [ ] 4.3 Implement grading loop: on grade, call `total-recall-sched--sm2-grade`, persist updated schedule via adapter, advance to next card or re-queue wrong card at end of session queue; on session completion, display summary (correct/wrong counts) with `q` to close
- [ ] 4.4 Add autoload cookie for `total-recall-train` in the main `total-recall.el`

## 5. Tests — training session (TDD: failing test, then minimal implementation, then refactor)

- [ ] 5.1 Test that training session with no due items shows a message and does not enter the training buffer
- [ ] 5.2 Test that a training session with due items enters the buffer, displays the card prompt hidden, and reveals on SPC
- [ ] 5.3 Test that grading a card correct persists the updated schedule and advances the queue
- [ ] 5.4 Test that grading a card wrong persists the updated schedule, re-queues the card at the end, and the card appears again before the session ends
- [ ] 5.5 Test that "both" direction creates two queue entries per due item (forward + backward) and that grading each updates its respective schedule independently
- [ ] 5.6 Test tag filtering: session with a tag includes only items with that tag
