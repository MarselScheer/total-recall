## Purpose

Defines the SQLite persistence layer — database lifecycle, table schemas, and the adapter function interface that all higher-level code depends on.

## ADDED Requirements

### Requirement: Storage adapter is a plist of functions
The storage adapter SHALL be initialized by calling `total-recall-storage-init` with a database path, returning a plist of adapter functions.

#### Scenario: Storage init returns adapter plist
- **WHEN** storage is initialized with a database path
- **THEN** the result SHALL be a plist with keys `:load-item`, `:save-item`, `:delete-item`, `:load-schedule`, `:save-schedule`, `:query-due`, `:query-by-tag`, `:list-all-tags`, `:query-all`
- **AND** each value SHALL be a function

#### Scenario: Storage init with nil path uses :memory:
- **WHEN** storage is initialized with nil as the database path
- **THEN** it SHALL create an in-memory SQLite database
- **AND** adapter functions SHALL work normally

### Requirement: Storage creates tables on init
Initializing storage SHALL create the `items`, `schedule`, and `related` tables if they do not exist.

#### Scenario: Tables exist after init
- **WHEN** storage is initialized
- **THEN** the `items` table SHALL exist with columns `id`, `term`, `definition`, `tags`, `depth`, `examples`, `analogy`, `notes`, `created`, `modified`
- **AND** the `schedule` table SHALL exist with columns `item_id`, `interval`, `ease_factor`, `repetitions`, `next_review`, `last_review`, `lapses`
- **AND** the `related` table SHALL exist with columns `item_id`, `related_id`

### Requirement: Load-item returns an item closure
The `:load-item` adapter function SHALL take an item id and return an item closure, or nil if not found.

#### Scenario: Load existing item
- **WHEN** an item is saved and then loaded by its id
- **THEN** the loaded item SHALL have the same `:term` and `:definition` as the saved item

#### Scenario: Load non-existent item
- **WHEN** `(:load-item "nonexistent-id")` is called
- **THEN** it SHALL return nil

### Requirement: Save-item persists an item
The `:save-item` adapter function SHALL save an item closure to the database, upserting by id.

#### Scenario: Save new item
- **WHEN** a new item is saved to storage
- **THEN** loading that item by id SHALL return an item with matching data

#### Scenario: Save updates existing item
- **WHEN** an existing item is modified and saved again
- **THEN** loading the item SHALL return the updated values

### Requirement: Delete-item removes an item and cascade
The `:delete-item` adapter function SHALL delete an item and cascade to its schedule and related records.

#### Scenario: Delete removes item
- **WHEN** an existing item is deleted
- **THEN** loading it by id SHALL return nil

#### Scenario: Delete cleans up schedule
- **WHEN** an item with a schedule record is deleted
- **THEN** loading its schedule SHALL return nil

#### Scenario: Delete cleans up related
- **WHEN** an item that appears in `related` is deleted
- **THEN** querying relationships for that item SHALL return no results

### Requirement: Load-schedule returns a schedule closure
The `:load-schedule` adapter function SHALL take an item id and return a schedule closure, or nil if not found.

#### Scenario: Load existing schedule
- **WHEN** a schedule is saved and loaded by its item id
- **THEN** the loaded schedule SHALL have the same `:interval` and `:ease-factor` as the saved one

#### Scenario: Load schedule for item without one
- **WHEN** `(:load-schedule "item-without-schedule")` is called
- **THEN** it SHALL return nil

### Requirement: Query-all returns all item ids
The `:query-all` adapter function SHALL return a list of all item ids in the database.

#### Scenario: Query-all with items
- **WHEN** multiple items are saved
- **THEN** `(:query-all)` SHALL return a list containing all their ids

#### Scenario: Query-all with empty database
- **WHEN** no items are saved
- **THEN** `(:query-all)` SHALL return an empty list

### Requirement: List-all-tags returns every distinct tag
The `:list-all-tags` adapter function SHALL return a list of symbols representing every distinct tag across all items.

#### Scenario: List all tags with items that have tags
- **WHEN** items exist with tags `:german`, `:vocabulary`, and `:beginner`
- **THEN** `(:list-all-tags)` SHALL return a list containing those same symbols

#### Scenario: Duplicate tags across items are collapsed
- **WHEN** multiple items have the tag `:german`
- **THEN** `(:list-all-tags)` SHALL contain `:german` only once

#### Scenario: List all tags when no tags exist
- **WHEN** no items have any tags
- **THEN** `(:list-all-tags)` SHALL return nil