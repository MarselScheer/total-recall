## Context

See `proposal.md` for the motivation and scope. This is a greenfield Emacs Lisp package with no existing codebase. The key constraints shaping the design:

- Emacs 29+ only (for built-in SQLite support)
- No external package dependencies — use only `cl-lib`, `json.el`, `seq.el`
- Design follows the project's principles: plain `defun` (no `cl-defstruct`), dependency injection via function arguments, closures as models, testability as the quality signal
- SQLite via Emacs's built-in `sqlite-open`, `sqlite-execute`, `sqlite-select`

## Goals / Non-Goals

**Goals:**
- Define the item data structure as a plist wrapped in a closure (the "rich domain model" pattern)
- Define the scheduling record as a separate plist, also closure-wrapped
- Define the SQLite schema (tables, indices) and the storage adapter function interface
- Define the tag system — tags stored as a JSON array string in SQLite, with an Elisp API for add/remove/query
- Make every layer testable via injected dependencies and `:memory:` databases

**Non-Goals:**
- The SM-2 algorithm implementation (scheduling record data structure only)
- Any user-facing UI, keybindings, or commands
- Import/export functionality
- Migration from other formats
- Performance optimization beyond sensible defaults

## Decisions

### 1. Item as closure over plist (not cl-defstruct or alist)

**Decision**: An item is a function (a closure) created by a factory `total-recall-make-item`. It closes over its data plist and dispatches on a keyword argument.

```elisp
(defun total-recall-make-item (data)
  "Return an item closure operating on plist DATA."
  (lambda (command &rest args)
    (pcase command
      ('get (plist-get data (car args)))
      ('set (setq data (plist-put data (car args) (cadr args))))
      ('serialize data)
      ('update (apply #'total-recall-item-update data args)))))
```

**Rationale**: Plists are the most Emacs-native structured data type. Using `pcase` dispatch gives us method-like behavior without `cl-defstruct` (which the design principles forbid). The raw plist is accessible via `(item 'serialize)` for persistence, keeping serialization trivial.

**Alternatives considered**:
- Bare plist with accessor functions — functional but harder to evolve (every accessor needs a separate function, no encapsulation)
- Alist — redundant when plists handle key-value natively
- Hash table — overkill for the small number of fields per item

### 2. Scheduling record as separate closure

**Decision**: Scheduling state is a separate closure, created by `total-recall-make-schedule`, wrapping its own plist with the same `get`/`set`/`serialize` dispatch pattern.

```elisp
(defun total-recall-make-schedule (plist)
  (lambda (command &rest args)
    (pcase command
      ('get (plist-get plist (car args)))
      ('set (setq plist (plist-put plist (car args) (cadr args))))
      ('serialize plist))))
```

**Rationale**: The core insight from exploration — testability. A scheduling test can hand any schedule record to a function without worrying about item content. Changing the scheduling algorithm never touches item code. Resetting stats means clearing schedule records, leaving items intact.

**Alternatives considered**: Inline scheduling keys on the item plist — simpler lookup, but violates separation of concerns and makes tests harder to write (every test setup needs to include scheduling keys even for non-scheduling tests).

### 3. Tags stored as JSON string in a TEXT column

**Decision**: Tags are stored as `json-encode`'d list of symbols in a single TEXT column on the items table. The Elisp API `total-recall-tag--add`, `total-recall-tag--remove`, `total-recall-tag--items` handle the encoding/decoding round-trip.

**Rationale**: Avoids a separate `item_tags` join table (simpler schema, fewer queries). SQLite can still query into JSON strings with `json_extract()` if needed. The tag set per item is typically small (3-10 tags).

**Alternatives considered**:
- Separate `tags` and `item_tags` tables — normalized, but adds query complexity for a small data set
- Tags as individual columns — doesn't scale, can't support arbitrary tags
- Tags as a plist key managed only in Elisp — no persistence query capability

**Distinct tag query**: Listing all available tags across items uses SQLite's `json_each()` table-valued function applied to the tags column across all rows. This avoids loading every item into Elisp just to extract tag names. The adapter function `:list-all-tags` SHALL run a `SELECT DISTINCT value FROM items, json_each(items.tags) ORDER BY value` query and convert each result back to a symbol.

### 4. Storage adapter as injected function interface (not a class)

**Decision**: The storage layer exposes a set of functions that higher layers inject as arguments. The adapter is wired together at a factory/composition-root level.

```elisp
;; Adapter functions created by total-recall-storage-init
;; Returns a plist of functions:
;;   :load-item     (fn id) → item-closure | nil
;;   :save-item     (fn item) → nil
;;   :delete-item   (fn id) → nil
;;   :load-schedule (fn id) → schedule-closure | nil
;;   :save-schedule (fn schedule) → nil
;;   :query-due     (fn limit) → list of (item-id . item-closure)
;;   :query-by-tag  (fn tag) → list of item-closure
;;   :list-all-tags (fn) → list of symbols
;;   :query-all     (fn) → list of item-id
```

**Rationale**: Follows the design principles — dependency injection instead of hardcoded calls. Test a review session by passing mock functions that return known items. Swap backends by writing a new adapter that returns the same function interface.

**Alternatives considered**:
- Global variables + `let` overrides — works but the injection boundary is implicit and leaky
- `advice-add` around storage functions — violates the "advice-add signals a missing injection point" rule

### 5. SQLite schema with separate items, schedule, and related tables

**Decision**: Three tables in the SQLite database:

```sql
CREATE TABLE IF NOT EXISTS items (
  id         TEXT PRIMARY KEY,
  term       TEXT NOT NULL,
  definition TEXT NOT NULL,
  tags       TEXT NOT NULL DEFAULT '[]',
  depth      INTEGER NOT NULL DEFAULT 3,
  examples   TEXT NOT NULL DEFAULT '[]',
  analogy    TEXT DEFAULT NULL,
  notes      TEXT DEFAULT NULL,
  created    TEXT NOT NULL,
  modified   TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS schedule (
  item_id     TEXT PRIMARY KEY REFERENCES items(id) ON DELETE CASCADE,
  interval    REAL NOT NULL DEFAULT 0,
  ease_factor REAL NOT NULL DEFAULT 2.5,
  repetitions INTEGER NOT NULL DEFAULT 0,
  next_review TEXT NOT NULL,
  last_review TEXT DEFAULT NULL,
  lapses      INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS related (
  item_id    TEXT NOT NULL REFERENCES items(id) ON DELETE CASCADE,
  related_id TEXT NOT NULL REFERENCES items(id) ON DELETE CASCADE,
  PRIMARY KEY (item_id, related_id)
);
```

**Rationale**: Flat, normalized layout. `ON DELETE CASCADE` means deleting an item cleans up its schedule and relationships automatically. The `examples` TEXT column stores JSON (array of `(text . props)` pairs), encoded/decoded by `json.el`.

### 6. ID generation via Emacs built-in

**Decision**: IDs are generated using `(format "%s-%s" (time-to-seconds (current-time)) (random 9999))` — simple, unique enough for personal use. No UUID library dependency.

**Rationale**: UUID generation requires an external library or a shell call. For a single-user Emacs package, a timestamp + random suffix is collision-free in practice.

## Risks / Trade-offs

- **[Risk] JSON in TEXT columns (`tags`, `examples`) is not type-safe** — a malformed JSON string from a bug could corrupt that item. → **Mitigation**: All tag and example operations go through dedicated `total-recall-tag--*` and `total-recall-item--*` helper functions that validate the JSON round-trip before writing.
- **[Risk] SQLite dependency locks us into Emacs 29+** — users on 27/28 can't use this package. → **Mitigation**: Accept this as a deliberate choice. SQLite is a major quality jump over file-based storage.
- **[Risk] The closure-over-plist pattern is unfamiliar to some Elisp developers** — it's not the most common Emacs idiom. → **Mitigation**: The design principles explicitly endorse this pattern (closures as rich domain models). Document the pattern clearly in the code.
- **[Trade-off] No in-memory cache at this stage** — every `load-item` call does a SQLite query. For a review session querying scores of items, this is fine. For a buffer listing 2000 items, it would be slow. → We accept this for now; a cache layer can be added later without changing the adapter interface.