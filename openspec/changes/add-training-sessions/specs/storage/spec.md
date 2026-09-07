## MODIFIED Requirements

### Requirement: Storage creates tables on init
Initializing storage SHALL create the `items`, `schedule`, and `related` tables if they do not exist.

#### Scenario: Tables exist after init
- **WHEN** storage is initialized
- **THEN** the `items` table SHALL exist with columns `id`, `term`, `definition`, `tags`, `depth`, `examples`, `analogy`, `notes`, `created`, `modified`
- **AND** the `schedule` table SHALL exist with columns `item_id`, `direction`, `interval`, `ease_factor`, `repetitions`, `next_review`, `last_review`, `lapses`
- **AND** the `schedule` table SHALL have a composite primary key `(item_id, direction)`
- **AND** the `related` table SHALL exist with columns `item_id`, `related_id`

### Requirement: Load-schedule returns a schedule closure by direction
The `:load-schedule` adapter function SHALL take an item id and a direction string (`"forward"` or `"backward"`) and return a schedule closure, or nil if not found.

#### Scenario: Load existing schedule with direction
- **WHEN** a schedule for "abc-123" / `"forward"` is saved and loaded with the same id and direction
- **THEN** the loaded schedule SHALL have the same `:interval` and `:ease-factor` as the saved one

#### Scenario: Load schedule for wrong direction returns nil
- **WHEN** a schedule exists for direction `"forward"` but `(:load-schedule "abc-123" "backward")` is called
- **THEN** it SHALL return nil

#### Scenario: Load schedule for item without one
- **WHEN** `(:load-schedule "item-without-schedule" "forward")` is called
- **THEN** it SHALL return nil

### Requirement: Save-schedule persists a schedule for a given direction
The `:save-schedule` adapter function SHALL save a schedule closure to the database, upserting by `(item_id, direction)`.

#### Scenario: Save new schedule with direction
- **WHEN** a schedule with direction `"forward"` is saved
- **THEN** loading it with the same id and direction SHALL return matching data

#### Scenario: Forward and backward schedules coexist independently
- **WHEN** both a forward and a backward schedule are saved for the same item id
- **THEN** loading with direction `"forward"` SHALL return the forward data
- **AND** loading with direction `"backward"` SHALL return the backward data

### Requirement: Query-due returns due items for a given direction
The `:query-due` adapter function SHALL take a direction string (`"forward"` or `"backward"`) and return a list of item closures whose schedule records for that direction have `next-review` <= current time.

#### Scenario: Query-due filters by direction
- **WHEN** items have forward and backward schedules with different next-review times
- **THEN** `(:query-due "forward")` SHALL return only items whose forward schedule is due
- **AND** `(:query-due "backward")` SHALL return only items whose backward schedule is due

#### Scenario: Query-due with no due items returns empty
- **WHEN** no schedule records for the given direction have `next-review` in the past
- **THEN** `(:query-due "forward")` SHALL return an empty list

### Requirement: Deleting an item deletes both schedule directions
Deleting an item from the storage SHALL delete both its forward and backward schedule records.

#### Scenario: Both schedule directions are cleaned up on item deletion
- **WHEN** an item with both forward and backward schedules is deleted from storage
- **THEN** querying for either direction SHALL return nil