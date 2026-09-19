## MODIFIED Requirements

The existing training requirements are unchanged. The following requirements are added.

## ADDED Requirements

### Requirement: User can edit the current item from the training buffer

The training buffer SHALL provide an `E` keybinding (uppercase) to open an edit buffer when the answer is revealed. The edit buffer SHALL display the current item's editable fields in `key:: value` format (the same format used by the capture template). The user SHALL be able to commit changes or cancel.

Editable fields: `term`, `definition`, `tags`, `depth`, `examples`, `notes`, `analogy`.

#### Scenario: Edit is available when answer is revealed [SC-2026-09-19_12-33-15-01]

- **WHEN** the answer is revealed and the user presses `E`
- **THEN** an edit buffer SHALL open displaying the current item's fields in `key:: value` format
- **AND** the buffer SHALL contain term::, definition::, tags::, depth::, examples::, notes::, analogy:: with current values pre-filled

#### Scenario: Edit is disabled when answer is hidden [SC-2026-09-19_12-33-15-02]

- **WHEN** the answer is hidden and the user presses `E`
- **THEN** nothing SHALL happen (the keybinding has no effect)

#### Scenario: Commit persists changes [SC-2026-09-19_12-33-15-03]

- **WHEN** the user modifies a field (e.g., `definition::`) in the edit buffer and presses `C-c C-c`
- **THEN** the item's definition SHALL be updated in storage to the new value
- **AND** the item's `:modified` timestamp SHALL be updated
- **AND** the edit buffer SHALL close
- **AND** the training buffer SHALL show the updated data

#### Scenario: Commit does not modify schedule [SC-2026-09-19_12-33-15-04]

- **WHEN** the user edits an item's content and presses `C-c C-c`
- **THEN** the schedule records for that item (both forward and backward) SHALL be unchanged
- **AND** the schedule data (interval, ease-factor, repetitions, next-review, last-review, lapses) SHALL remain as before the edit

#### Scenario: Commit preserves id and created timestamp [SC-2026-09-19_12-33-15-05]

- **WHEN** the user presses `C-c C-c` after editing
- **THEN** the item's `:id` SHALL equal the original item's `:id`
- **AND** the item's `:created` SHALL equal the original item's `:created`

#### Scenario: Cancel discards changes [SC-2026-09-19_12-33-15-06]

- **WHEN** the user modifies the edit buffer and presses `C-c C-k`
- **THEN** the edit buffer SHALL close
- **AND** the item in storage SHALL be unchanged
- **AND** the training buffer SHALL return with the original data intact

#### Scenario: Term or definition cannot be empty [SC-2026-09-19_12-33-15-07]

- **WHEN** the user clears the `term::` or `definition::` field and presses `C-c C-c`
- **THEN** the commit SHALL signal an error
- **AND** the edit buffer SHALL remain open for correction

#### Scenario: Edited item is immediately updated in the training display [SC-2026-09-19_12-33-15-08]

- **WHEN** the user commits an edit
- **THEN** the training buffer SHALL be re-rendered with the updated field values
- **AND** the current card position and session progress SHALL be preserved