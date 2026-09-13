## MODIFIED Requirements

### Requirement: Commit parses, creates, saves, and initializes schedule
The commit function SHALL parse the buffer, create an item from the parsed data, persist it, and create initial schedule entries so the item is immediately due for review.

#### Scenario: Commit persists valid capture data `[SC-2026-09-12_19-38-38-01]`
- **WHEN** the commit function processes a valid capture buffer
- **THEN** a new item SHALL be created from the parsed data and persisted
- **AND** the function SHALL return the new item's identifier

#### Scenario: Commit creates forward and backward schedule for new item `[SC-2026-09-12_19-38-38-02]`
- **WHEN** the commit function processes a valid capture buffer
- **THEN** a forward schedule SHALL exist for the new item with `:next-review` set to now (immediately due)
- **AND** a backward schedule SHALL exist for the new item with `:next-review` set to now (immediately due)

#### Scenario: Commit with empty buffer does nothing `[SC-2026-09-12_19-38-38-03]`
- **WHEN** the commit function processes an empty (or comment-only) buffer
- **THEN** it SHALL NOT save anything
- **AND** it SHALL signal an error or cancel the capture