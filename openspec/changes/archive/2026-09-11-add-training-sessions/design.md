## Context

The system currently captures and persists memorization items with tag-based organization and single-track SM-2 scheduling (see proposal.md — Why). The storage adapter's `:query-due` is a stub returning nil. There is no interactive review mechanism.

Key constraints from the codebase design principles (dependency injection, closure-based models, testability):

- The training module must not hardcode storage or scheduling — these are injected.
- The schedule data model (`total-recall-sched.el`) uses plist-based closures, not classes.
- The storage adapter is a plist of functions, not an object.

## Goals / Non-Goals

**Goals:**
- Interactive training buffer where the user sees one card at a time, reveals the answer, and grades it (correct/wrong)
- Dual-track scheduling: forward (term→definition) and backward (definition→term) tracked with independent SM-2 state
- Single-tag filtering at session start
- "Both" mode that queues each item twice (forward + backward), respecting each track's independent due dates
- Binary grading (correct/wrong) mapped to SM-2 quality 5 / 0
- Pure SM-2 grading function in the scheduling module

**Non-Goals:**
- Complex tag expressions (union, intersection, negation) — defer to a future change
- Anki-style graded quality scale (0-5) — binary is sufficient for the initial release
- Session statistics persistence or long-term history — summary shown at end only
- Algorithm changes to SM-2 — standard SM-2 update rules

## Decisions

### Decision 1: Separate schedule records per direction (dual track)

**Choice:** Two rows in the `schedule` table, keyed by `(item_id, direction)`.

**Alternatives considered:**
- Single schedule row with extra fields (`forward-interval`, `backward-interval`, etc.) — would bloat the schema and complicate the schedule closure with conditional logic.
- Two separate tables — unnecessary; a `direction` column keeps queries simple with `WHERE item_id = ? AND direction = ?`.

**Rationale:** Forward and backward recall have different difficulty curves. A word you've seen 10 times (forward) may still be hard to produce from its definition (backward). Independent intervals are the SM-2-correct approach and follow real flashcard practice (Anki does this with separate card types).

### Decision 2: Binary grading mapped to SM-2 quality 0 and 5

**Choice:** `c` → quality 5 (perfect recall), `w` → quality 0 (complete forgetting).

**Alternatives considered:**
- Full 0-5 quality scale — gives finer gradation but requires the user to make nuanced judgments, slowing down the training flow.
- 3-point scale (again/hard/good) — maps to Anki's model but adds complexity to the keybindings and the SM-2 mapping.

**Rationale:** Binary is fast, unambiguous, and maps cleanly to SM-2's quality extremes. Quality 0 resets the schedule (lapse +1, repetitions to 0, interval to 0). Quality 5 gives the maximum interval boost. This follows the project's principle of starting simple.

### Decision 3: Dedicated interactive buffer via `total-recall-train-mode`

**Choice:** A major mode with `SPC` (reveal), `c` (correct), `w` (wrong), `q` (quit). The buffer displays the current card, position, and keybinding hint.

**Alternatives considered:**
- Minibuffer prompts — simpler to implement but loses visual structure (can't show a progress display comfortably).
- Org-mode integration — too heavyweight; the training flow is fundamentally different from capture.

**Rationale:** A dedicated mode is the cleanest UX for an Anki-like training flow. Position tracking, hidden answers, and per-card state are all local to the buffer.

### Decision 4: Queue built at session start, not streaming

**Choice:** Build the full queue of due items (filtered by tag/direction) before entering the buffer. The queue is a list of `(item . direction)` pairs.

**Alternatives considered:**
- Streaming query (fetch next due card each time) — would handle inter-session schedule updates but adds complexity.

**Rationale:** Sessions are short (typically 10-50 cards). Building the full queue is simple, testable, and avoids mid-session query inconsistency. Schedule updates are persisted per-card during the session, so a crash doesn't lose progress.

### Decision 5: SM-2 grading is a pure function on the schedule module

**Choice:** `total-recall-sched--sm2-grade` takes a quality (0 or 5) and a schedule closure, returns a new schedule plist. It does NOT persist; the caller handles saving.

**Rationale:** Matches the project's dependency-injection and testability principles. The function can be tested without storage:
```elisp
(let ((sched (total-recall-make-schedule ...)))
  (total-recall-sched--sm2-grade 5 sched))
```

### Decision 6: Schedule data model accepts direction at creation

**Choice:** `total-recall-make-schedule` takes `:direction` in its data plist, defaults to `"forward"`.

**Rationale:** Consistency with the existing pattern (defaults applied in factory). The existing schedule closure interface (`'get`, `'set`, `'serialize`) remains unchanged, maintaining backward compatibility for callers that don't need direction.

### Decision 7: Session configuration via interactive prompts

**Choice:** `total-recall-train` uses `read-char-choice` for direction and `completing-read` for tag (with `nil` meaning "all"). No prefix-arg or customization variables.

**Rationale:** Minimal config surface. The prompts are interactive and self-explanatory. Future enhancement could add customization options, but this follows "start simple."

### Decision 8: Wrong cards are re-queued at the end of the session

**Choice:** When the user grades a card wrong (`w`), the card is placed back at the end of the session queue. It appears again later in the same session.

**Alternatives considered:**
- No re-queueing — simpler but gives the user no chance to correct a missed card within the session.
- Immediate retry — interrupts the flow and doesn't test spaced recall.

**Rationale:** Re-queueing at the end gives the user a chance to recall the same card again before the session ends, which reinforces learning. This matches Anki's "again" behavior. The user keeps the same card in memory, so the second encounter tests whether the material has been consolidated.

## Risks / Trade-offs

- **Schema migration for existing users**: The `schedule` table gains a `direction` column and a composite PK. Existing single-track data has no direction — these rows are orphaned after migration. **Mitigation:** Since this is a learning project with no production users, the migration is a one-time `DROP TABLE IF EXISTS schedule` / recreate. For a real rollout, we'd migrate existing rows with direction "forward".
- **"Both" mode doubles session length**: A user with 20 due items gets 40 queue entries. Could feel tedious. **Mitigation:** The user explicitly chooses "both" — it's opt-in.
- **Mid-session, new items become due**: The queue is fixed at session start, so items that fall due during a session are not included. **Mitigation:** Sessions are short; the user just starts another session.
- **Single-tag filter limits power users**: Cannot train on `:german AND :vocabulary`. **Mitigation:** Declared non-goal; easy to extend later with a tag-expression parser.

### Decision 9: Queue is shuffled at session start, not sorted by due date

**Choice:** The session queue is shuffled (random order) before entering the training buffer.

**Alternatives considered:**
- Sort by next-review ascending (most overdue first) — prioritizes stale cards but creates a predictable, boring order and doesn't interleave items from different tags or directions.
- No shuffle, insert in query order — depends on database implementation order, which is undefined.

**Rationale:** Shuffling ensures variety within a session — adjacent cards test different items, reducing interference and making each session feel fresh. Because all items in the queue are due (past their next-review), ordering by overdue time has marginal benefit: any of them are fair game for review. Shuffling also simplifies the implementation since the queue is built once at start and order doesn't matter.

### Decision 10: SM-2 ease-factor follows the standard formula with 1.3 floor

**Choice:** `EF' = EF + (0.1 - (5 - q) × (0.08 + (5 - q) × 0.02))`, clamped to a minimum of 1.3.

- Quality 5 (correct): `EF' = EF + 0.1` — ease factor increases slightly.
- Quality 0 (wrong): `EF' = EF - 0.8` — ease factor decreases significantly.

**Alternatives considered:**
- Fixed ease-factor — simpler but doesn't adapt to card difficulty.
- Different delta values — standard SM-2 formula is well-studied and predictable.

**Rationale:** Documents the exact formula so all scenarios share a single source of truth. The 1.3 floor prevents ease-factor from dropping so low that intervals never grow. This parallels the existing "minimum floor" scenario and makes the EF behavior testable without reverse-engineering the code.