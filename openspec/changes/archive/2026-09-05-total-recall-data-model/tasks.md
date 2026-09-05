## 1. Item Model

- [x] 1.1 Implement `total-recall-make-item` factory function (closure over plist with `get`, `set`, `serialize` dispatch) and verify unit tests pass for all required and optional fields
- [x] 1.2 Implement ID generation (`format "%s-%s" (time-to-seconds (current-time)) (random 9999)`) and verify generated IDs are non-nil strings of the correct format
- [x] 1.3 Verify serialization round-trip: `(item 'serialize)` produces a plist that `json-encode`/`json-decode` can round-trip through `total-recall-make-item`

## 2. Schedule Model

- [x] 2.1 Implement `total-recall-make-schedule` factory function (closure over plist with `get`, `set`, `serialize` dispatch) and verify unit tests pass for all required fields with correct default values
- [x] 2.2 Verify schedule serialization round-trip: `(schedule 'serialize)` produces a plist that survives JSON encode/decode

## 3. Storage Layer

- [x] 3.1 Implement `total-recall-storage-init` that creates an in-memory (`:memory:`) or file-backed SQLite database, creates the three tables (`items`, `schedule`, `related`) with correct schemas, and returns an adapter plist with all required function keys
- [x] 3.2 Implement `:load-item` and `:save-item` adapter functions (upsert by id) and verify save-then-load round-trip preserves all item data
- [x] 3.3 Implement `:delete-item` with `ON DELETE CASCADE` and verify it removes item, schedule, and related records
- [x] 3.4 Implement `:load-schedule` and `:save-schedule` adapter functions and verify save-then-load round-trip
- [x] 3.5 Implement `:query-all` adapter function and verify it returns all item ids
- [x] 3.6 Implement `:query-by-tag` adapter function that filters items by JSON-encoded tag and verify it returns correct results
- [x] 3.7 Implement `:list-all-tags` adapter function that uses `json_each()` to return every distinct tag across all items and verify it collapses duplicates, handles items with no tags, and works on an empty database

## 4. Tag System

- [x] 4.1 Implement `total-recall-tag--add` function that adds tags to an item and verify idempotency (no duplicates)
- [x] 4.2 Implement `total-recall-tag--remove` function that removes tags from an item and verify it handles non-existent tags gracefully
- [x] 4.3 Implement `total-recall-tag--list-all` function that delegates to `:list-all-tags` on the storage adapter and verify it returns every distinct tag (nil when no items have tags, duplicates collapsed)

## 5. Integration Wiring

- [x] 5.1 Write integration test that creates items via the factory, tags them, saves to SQLite, loads them back, and asserts all data is preserved — verifying the full pipeline works end-to-end