## Purpose

Provides an interactive training session within Emacs where users review memorization items through spaced repetition, with dual-direction recall (term→definition and definition→term tracked independently) and binary grading.

## ADDED Requirements

### Requirement: User can start a training session
The system SHALL provide an interactive command `total-recall-train` that prompts the user for a direction and an optional tag filter before starting the session.

#### Scenario: Start training prompts for direction `[SC-2026-09-09_18-29-07-22]`
- **WHEN** `M-x total-recall-train` is invoked
- **THEN** the user SHALL be prompted to choose a direction: `"forward"`, `"backward"`, or `"both"`

#### Scenario: Start training prompts for optional tag `[SC-2026-09-09_18-29-07-23]`
- **WHEN** the user has selected a direction
- **THEN** the user SHALL be prompted for an optional tag (keyword symbol)
- **AND** when the user provides a tag, only items with that tag SHALL be included in the session
- **AND** when the user skips the tag, all due items SHALL be included

### Requirement: Training buffer shows the current card
The training session SHALL display cards in a dedicated buffer using `total-recall-train-mode`.

#### Scenario: Buffer displays current card prompt `[SC-2026-09-09_18-29-07-24]`
- **WHEN** the training buffer opens with the first card
- **THEN** the buffer SHALL display the card's prompt side (term for forward, definition for backward)
- **AND** the answer side SHALL be hidden

#### Scenario: Buffer shows progress `[SC-2026-09-09_18-29-07-25]`
- **WHEN** the training buffer displays a card
- **THEN** the buffer SHALL show the current position (e.g., "3/20")
- **AND** the buffer SHALL show the total number of cards in the session

#### Scenario: Buffer shows grading hint `[SC-2026-09-09_18-29-07-26]`
- **WHEN** the training buffer displays a card
- **THEN** the buffer SHALL show the keybinding hint "SPC to reveal | w wrong | c correct"
- **AND** the grading keys SHALL be disabled until the answer is revealed

### Requirement: User can reveal the answer
The system SHALL reveal the answer side of the current card when the user presses SPC.

#### Scenario: Reveal shows the answer `[SC-2026-09-09_18-29-07-27]`
- **WHEN** the user presses SPC on a card with hidden answer
- **THEN** the answer side SHALL be displayed
- **AND** the grading keys SHALL become enabled

### Requirement: User can grade a card as correct or wrong
The system SHALL accept binary grading via keybindings: `c` for correct, `w` for wrong.

#### Scenario: Grade correct advances the card's schedule `[SC-2026-09-09_18-29-07-28]`
- **WHEN** the user presses `c` after revealing the answer
- **THEN** `total-recall-sched--sm2-grade` SHALL be called with quality 5 on the current card's schedule
- **AND** the updated schedule SHALL be persisted

#### Scenario: Grade wrong resets the card's schedule `[SC-2026-09-09_18-29-07-29]`
- **WHEN** the user presses `w` after revealing the answer
- **THEN** `total-recall-sched--sm2-grade` SHALL be called with quality 0 on the current card's schedule
- **AND** the updated schedule SHALL be persisted

#### Scenario: Grade wrong re-queues the card at end of session `[SC-2026-09-09_18-29-07-30]`
- **WHEN** the user presses `w` after revealing the answer
- **THEN** the card SHALL be placed back at the end of the session queue
- **AND** the card SHALL appear again after all remaining cards have been graded
- **AND** the summary at session end SHALL reflect only the final grade for that card

#### Scenario: Grading advances to the next card `[SC-2026-09-09_18-29-07-31]`
- **WHEN** any grade is given
- **THEN** the buffer SHALL advance to the next card in the queue
- **AND** the new card's prompt SHALL be displayed with the answer hidden

#### Scenario: Grading a card before reveal is disabled `[SC-2026-09-09_18-29-07-32]`
- **WHEN** the answer is hidden
- **THEN** pressing `c` or `w` SHALL have no effect

### Requirement: Session ends when all cards are graded
The training session SHALL finish when every card in the queue has been graded.

#### Scenario: Session completion shows summary `[SC-2026-09-09_18-29-07-33]`
- **WHEN** the last card in the queue is graded
- **THEN** the buffer SHALL display a summary with count of correct and wrong answers
- **AND** the buffer SHALL prompt to close it (e.g., "Press q to close")

#### Scenario: User can quit the session early `[SC-2026-09-09_18-29-07-34]`
- **WHEN** the user presses `q` at any point during the session
- **THEN** the training buffer SHALL close
- **AND** any schedule updates already made SHALL be persisted

### Requirement: "Both" mode creates two independent queue entries
When the user selects "both" as the direction, each due item SHALL appear twice in the queue — once as forward (term→definition) and once as backward (definition→term) — each with its own schedule track.

#### Scenario: Both mode queues forward and backward for each due item `[SC-2026-09-09_18-29-07-35]`
- **WHEN** the user selects "both" and 3 items are due
- **THEN** the queue SHALL contain 6 entries
- **AND** grading the forward entry SHALL update only the forward schedule
- **AND** grading the backward entry SHALL update only the backward schedule

#### Scenario: Both mode respects independent due dates `[SC-2026-09-09_18-29-07-36]`
- **WHEN** an item's forward schedule is due but its backward schedule is not
- **THEN** "both" mode SHALL include only the forward entry for that item

### Requirement: Queue is shuffled before the session starts
The session queue SHALL be randomly shuffled before entering the training buffer, regardless of direction mode.

#### Scenario: Queue is shuffled at session start `[SC-2026-09-09_18-29-07-37]`
- **WHEN** the session queue is built
- **THEN** the order of items in the queue SHALL be randomized
- **AND** an item's position in the queue SHALL not correspond to its due-date order or database insertion order

#### Scenario: Both-mode queue preserves shuffle across directions `[SC-2026-09-09_18-29-07-38]`
- **WHEN** "both" mode produces 6 entries (3 items × 2 directions)
- **THEN** the 6 entries SHALL be shuffled as a single flat list
- **AND** forward and backward entries for the same item SHALL not be adjacent (except by chance)