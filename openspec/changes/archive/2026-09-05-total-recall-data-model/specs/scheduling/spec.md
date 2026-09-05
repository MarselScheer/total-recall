## Purpose

Defines the scheduling record that tracks spaced-repetition state for each item — interval, ease factor, repetition count, and review timestamps — enabling the SM-2 algorithm (implementation in a future change).

## ADDED Requirements

### Requirement: Scheduling record has required fields
Every schedule SHALL have `:item-id`, `:interval`, `:ease-factor`, `:repetitions`, `:next-review`, and `:lapses`.

#### Scenario: New schedule has default values
- **WHEN** a new schedule is created for an item
- **THEN** `:interval` SHALL be 0.0
- **AND** `:ease-factor` SHALL be 2.5
- **AND** `:repetitions` SHALL be 0
- **AND** `:lapses` SHALL be 0

#### Scenario: New schedule has a next-review timestamp
- **WHEN** a new schedule is created
- **THEN** `:next-review` SHALL be a non-nil string (ISO-8601 timestamp)

#### Scenario: Item id is available on schedule
- **WHEN** a schedule is created for item with id "abc-123"
- **THEN** `(schedule 'get :item-id)` SHALL equal "abc-123"

### Requirement: Scheduling record supports get and set
A schedule SHALL support the same `'get` and `'set` dispatch as items.

#### Scenario: Get value from schedule
- **WHEN** `(schedule 'get :interval)` is called
- **THEN** it SHALL return the current interval

#### Scenario: Set value on schedule
- **WHEN** `(schedule 'set :repetitions 3)` is called
- **THEN** `(schedule 'get :repetitions)` SHALL equal 3

### Requirement: Scheduling record supports serialize
A schedule SHALL support the `'serialize` command to return its raw plist.

#### Scenario: Serialize returns schedule plist
- **WHEN** `(schedule 'serialize)` is called
- **THEN** it SHALL return a plist with all scheduling keys

### Requirement: Items due for review are queryable
The storage adapter SHALL support querying schedule records where `:next-review` is in the past or now.

#### Scenario: Query returns due items
- **WHEN** the storage adapter is queried for due items
- **THEN** it SHALL return only items whose `next-review` is <= the current time

#### Scenario: Query returns empty when none are due
- **WHEN** no schedule records have `next-review` in the past
- **THEN** the due-items query SHALL return an empty list

### Requirement: Deleting an item deletes its schedule
Deleting an item from the storage SHALL also delete its associated schedule record.

#### Scenario: Schedule is cleaned up on item deletion
- **WHEN** an item is deleted from storage
- **THEN** querying for its schedule SHALL return nil