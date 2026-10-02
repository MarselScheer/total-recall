## 1. Levenshtein Distance Implementation

- [x] 1.1 Implement `total-recall-search--levenshtein-distance` function in `total-recall-search.el` — a pure Elisp function taking two string arguments and returning the Levenshtein edit distance (integer). Use a 2-row dynamic programming approach. Verify that the file compiles without errors (`emacs --batch --eval '(byte-compile-file "total-recall-search.el")'`).
- [x] 1.2 Write ERT tests in `tests/test-search.el` covering: equal strings (distance 0), one empty string, single insertion/deletion, single substitution, general multi-edit distance, and asymmetric cases (e.g., "abc" vs "abcdef"). Verify all tests pass (`mise run test`).

## 2. Search Command

- [x] 2.1 Implement `total-recall-search` interactive command that: grabs word at point via `(thing-at-point 'word t)`, loads all items from storage via `(:query-all)` + `(:load-item)`, computes Levenshtein distance to each item's term, sorts by ascending distance, truncates results to `total-recall-search-count` (default 5), and displays via `message`. Handle edge cases: no word at point, empty database, no close matches. Verify that `emacs --batch --eval '(byte-compile-file "total-recall-search.el")'` succeeds.
- [x] 2.2 Write ERT tests in `tests/test-search.el` covering: exact match appears first with distance 0, results sorted by distance, no word at point triggers message, empty database triggers message, and `total-recall-search-count` limits results. Use an in-memory storage adapter with pre-saved items. Verify all tests pass (`mise run test`).

## 3. Integration

- [x] 3.1 Add `(require 'total-recall-search)` to `total-recall.el` after the existing requires. Add `defcustom total-recall-search-count 5` with type `integer` and a docstring. Verify `emacs --batch -L . --eval '(require '\''total-recall)' --eval '(message "Loaded OK")'` succeeds and diagnostics are clean.
- [x] 3.2 Manual smoke test: start Emacs, initialize an in-memory adapter, save a few items with Russian terms (e.g., "храбрость", "храбрый", "слабость"), run `M-x total-recall-search` with point on "храбрый" in any buffer, verify the minibuffer shows the top matches sorted by distance.