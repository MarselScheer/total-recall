## Why

When reading Russian text in any Emacs buffer, you often encounter a word that feels similar to one already stored in your memorization database. Currently there's no way to quickly check — you'd have to manually scan or remember. A lightweight fuzzy search using Levenshtein distance lets you query the database by the word at point, without the complexity of embeddings or vector search.

## What Changes

- New module `total-recall-search.el` providing an interactive command `total-recall-search`
- Command grabs the word at point from any buffer and searches item terms via Levenshtein distance
- Results (top N, configurable via defcustom) displayed in the echo area, sorted by ascending distance
- No changes to existing modules or public API

## Capabilities

### New Capabilities

- `search`: Fuzzy search of memorization items by term similarity, using Levenshtein distance. Covers computing edit distance, querying all items from storage, sorting by distance, and displaying results in the minibuffer.

### Modified Capabilities

None — existing specs are unchanged. This is a pure addition.

## Impact

**Affected code:** One new file — `total-recall-search.el` — and an added `require` in `total-recall.el`. No changes to existing modules.

**Dependencies:** Uses the storage adapter (`:load-item` contract) and the item model (term access). Pure Emacs Lisp — no external libraries needed.