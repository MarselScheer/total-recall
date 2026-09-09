## MODIFIED Requirements

### Requirement: Scheduling record has required fields
Every schedule SHALL have `:item-id`, `:direction`, `:interval`, `:ease-factor`, `:repetitions`, `:next-review`, and `:lapses`.

#### Scenario: New schedule has default values
- **WHEN** a new schedule is created
- **THEN** `:interval` SHALL be 0.0
- **AND** `:ease-factor` SHALL be 2.5
- **AND** `:repetitions` SHALL be 0
- **AND** `:lapses` SHALL be 0
- **AND** `:direction` SHALL match the direction passed at creation

#### Scenario: Backward schedule has correct direction
- **WHEN** a new schedule is created for an item with direction `"backward"`
- **THEN** `:direction` SHALL be `"backward"`

#### Scenario: New schedule has a next-review timestamp
- **WHEN** a new schedule is created
- **THEN** `:next-review` SHALL be a non-nil string (ISO-8601 timestamp)

#### Scenario: Item id is available on schedule
- **WHEN** a schedule is created for item with id "abc-123"
- **THEN** `(schedule 'get :item-id)` SHALL equal "abc-123"

### Requirement: Items due for review are queryable by direction
The storage adapter SHALL support querying schedule records for a given direction where `:next-review` is in the past or now.

#### Scenario: Query returns due items for a direction
- **WHEN** the storage adapter is queried for due items with direction `"forward"`
- **THEN** it SHALL return only items with `direction = "forward"` whose `next-review` is <= the current time

#### Scenario: Query returns empty when none are due for that direction
- **WHEN** no schedule records for direction `"forward"` have `next-review` in the past
- **THEN** the due-items query for `"forward"` SHALL return an empty list

## ADDED Requirements

### Requirement: SM-2 binary grading evaluates a review attempt
The system SHALL provide a pure function `total-recall-sched--sm2-grade` that takes a quality score and a schedule closure and returns an updated schedule plist. Quality SHALL be 0 (wrong) or 5 (correct). A correct answer (quality 5) SHALL increment `:repetitions` by 1 regardless of the current value. A wrong answer (quality 0) SHALL reset `:repetitions` to 0 and SHALL increment `:lapses` by 1.

The interval SHALL follow the SM-2 progression driven by the updated `:repetitions`:

- After a correct answer that leaves `:repetitions` at 1, `:interval` SHALL be 1.0.
- After a correct answer that leaves `:repetitions` at 2, `:interval` SHALL be 6.0.
- After a correct answer that leaves `:repetitions` at 3 or more, `:interval` SHALL be the previous `:interval` multiplied by the current ease-factor.
- After a wrong answer, `:interval` SHALL be reset to 0.0.

The ease-factor update SHALL follow the standard SM-2 formula:

`EF' = EF + (0.1 - (5 - q) × (0.08 + (5 - q) × 0.02))`

where `q` is the quality score (0 or 5). The result SHALL be clamped to a minimum of 1.3.

- Quality 5 (correct): `EF' = EF + 0.1` — ease factor increases slightly.
- Quality 0 (wrong): `EF' = EF - 0.8` — ease factor decreases significantly.

#### Scenario: Correct answer advances the schedule
- **WHEN** `total-recall-sched--sm2-grade` is called with quality 5 on a first-review schedule (repetitions = 0, ease-factor = 2.5)
- **THEN** the returned plist SHALL have `:repetitions` equal to 1
- **AND** `:interval` SHALL be 1.0
- **AND** `:ease-factor` SHALL be 2.6

#### Scenario: Correct answer on second review sets 6-day interval
- **WHEN** `total-recall-sched--sm2-grade` is called with quality 5 on a schedule with repetitions = 1
- **THEN** the returned plist SHALL have `:repetitions` equal to 2
- **AND** `:interval` SHALL be 6.0

#### Scenario: Correct answer on subsequent reviews multiplies interval by ease-factor
- **WHEN** `total-recall-sched--sm2-grade` is called with quality 5 on a schedule with repetitions = 2 and interval = 6.0 and ease-factor = 2.5
- **THEN** the returned plist SHALL have `:repetitions` equal to 3
- **AND** `:interval` SHALL be 15.0

#### Scenario: Wrong answer resets the schedule
- **WHEN** `total-recall-sched--sm2-grade` is called with quality 0 on a schedule with ease-factor = 2.5
- **THEN** the returned plist SHALL have `:repetitions` equal to 0
- **AND** `:interval` SHALL be 0.0
- **AND** `:lapses` SHALL be incremented by 1
- **AND** `:ease-factor` SHALL be 1.7

#### Scenario: Ease factor has a minimum floor
- **WHEN** `total-recall-sched--sm2-grade` is called with quality 0 on a schedule with ease-factor = 1.5
- **THEN** the SM-2 formula raw result SHALL be 0.7
- **AND** the returned plist SHALL have `:ease-factor` equal to 1.3

#### Scenario: Schedule's last-review is updated after grading
- **WHEN** `total-recall-sched--sm2-grade` is called with any quality
- **THEN** the returned plist SHALL have `:last-review` set to the current timestamp
- **AND** `:next-review` SHALL be set to the current time plus the new interval