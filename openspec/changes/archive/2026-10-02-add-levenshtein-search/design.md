## Context

See `proposal.md — Why` and `specs/search/spec.md — Requirements`.

Current state: Total Recall has a storage adapter (`:query-all` returns all item ids, `:load-item` loads an item by id), and an item model closure (`:get :term` and `:get :definition` for field access). No search or fuzzy-match capability exists yet.

The storage adapter loads items one at a time — the search will iterate through all items.

## Goals / Non-Goals

**Goals:**
- A self-contained `total-recall-search` module with no new external dependencies
- Interactive command that works from any buffer where `thing-at-point` returns a word
- Results shown in the minibuffer as transient info (not a persistent buffer)

**Non-Goals:**
- No selection or follow-up action on results (purely informational for now)
- No vector search, embeddings, or phonetic algorithms
- No search across definitions, notes, or other item fields
- No persistent search history or caching

## Decisions

### Decision 1: Plain Levenshtein (not Damerau-Levenshtein or normalized)

**Rationale:** For written orthographic similarity, Levenshtein is the simplest correct algorithm. Adjacent transpositions (Damerau's addition) don't meaningfully improve Russian vocabulary matching — you're reading, not typing. Normalization (`distance / max(len1, len2)`) adds complexity without changing sort order significantly for similarly sized words in a vocab database. Can be added later in one line if needed.

**Alternatives considered:** Damerau-Levenshtein (overkill), Jaro-Winkler (prefix bias distorts for inflected languages), trigram overlap (weaker for morphological root sharing).

### Decision 2: Single function `total-recall-search--levenshtein-distance`

**Rationale:** Levenshtein distance is a well-known algorithm. A single pure function with two string arguments, no side effects, easily tested in isolation. Two-row DP (O(min(m,n)) space) rather than full matrix.

### Decision 3: Iterate all items in the command body

**Rationale:** The command calls `(:query-all)` then loops over ids loading each item via `(:load-item)`. This is O(n) synchronous calls into the storage adapter. Simple, correct, and the user agreed to optimize later if laggy.

**Alternatives considered:** Adding a batch-load function to the storage adapter (premature optimization for current database sizes).

### Decision 4: Minibuffer display via `message`

**Rationale:** The user wants a "quick minibuffer" experience — no selection, just info. `message` with format string shows in the echo area and disappears on the next command. Fits the flow: glance at results, continue reading.

**Alternatives considered:** `completing-read` (implies selection — explicitly not wanted), `with-output-to-temp-buffer` (too disruptive).

### Decision 5: Definition truncated to ~80 characters

**Rationale:** Minibuffer real estate is limited, especially with multiple results. Definitions can be long. Truncating each line to ~80 chars keeps results readable without wrapping.

### Decision 6: `total-recall-search-count` as a defcustom

**Rationale:** Configurable result count. `defcustom` puts it in the customization system. Default 5.

## Risks / Trade-offs

| Risk | Mitigation |
|---|---|
| **Large database causes lag** — loading all items synchronously blocks Emacs | User agreed to brute-force now, optimize later. Future options: add a batch-load adapter function, or lazy-load/cache items. |
| **Long definitions clutter minibuffer** — wide results hard to scan | Truncate definition display to ~80 chars. |
| **Non-word at point** — point on punctuation, whitespace, symbol | `thing-at-point 'word t` returns nil; command degrades gracefully with a message. |
| **Cyrillic vs Latin homoglyphs** — "а" (Cyrillic) vs "a" (Latin) differ in Unicode but look identical | Acceptable for v1. Unicode normalization could be a future improvement.