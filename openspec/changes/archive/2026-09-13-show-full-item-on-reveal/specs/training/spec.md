## MODIFIED Requirements

### Requirement: User can reveal the answer
The system SHALL reveal the answer side of the current card when the user presses SPC, and SHALL display all non-nil item fields and the current direction's schedule metadata.

#### Scenario: Reveal shows the answer and all item fields `[SC-2026-09-09_18-29-07-27]`
- **WHEN** the user presses SPC on a card with hidden answer
- **THEN** the answer side SHALL be displayed
- **AND** all non-nil item fields SHALL be shown below the answer: `:tags`, `:depth`, `:examples`, `:notes`, `:analogy`
- **AND** the schedule metadata for the current direction SHALL be shown: `:repetitions`, `:last-review`, `:lapses`
- **AND** the grading keys SHALL become enabled

## ADDED Requirements

### Requirement: Examples, notes, and analogy use distinct faces
When the answer is revealed, `:examples`, `:notes`, and `:analogy` SHALL each be rendered with a distinct, customizable face for visual distinction.

#### Scenario: Examples use a dedicated face `[SC-2026-09-12_22-02-42-01]`
- **WHEN** the answer is revealed and the item has `:examples`
- **THEN** the examples content SHALL be displayed under a heading "Examples"
- **AND** the examples text SHALL use the `total-recall-train-examples-face`

#### Scenario: Notes use a dedicated face `[SC-2026-09-12_22-02-42-02]`
- **WHEN** the answer is revealed and the item has `:notes`
- **THEN** the notes content SHALL be displayed under a heading "Notes"
- **AND** the notes text SHALL use the `total-recall-train-notes-face`

#### Scenario: Analogy uses a dedicated face `[SC-2026-09-12_22-02-42-03]`
- **WHEN** the answer is revealed and the item has `:analogy`
- **THEN** the analogy content SHALL be displayed under a heading "Analogy"
- **AND** the analogy text SHALL use the `total-recall-train-analogy-face`

#### Scenario: Missing fields are omitted `[SC-2026-09-12_22-02-42-04]`
- **WHEN** the answer is revealed and the item has nil `:examples`
- **THEN** no "Examples" heading SHALL be displayed
- **AND** the examples section SHALL be skipped entirely