## Purpose

Provides an interactive, template-driven way for users to create memorization items within Emacs using org-capture, with structured field editing and automatic persistence to the storage adapter.

## ADDED Requirements

### Requirement: Capture is invoked via org-capture
The system SHALL register an org-capture template so that entering `M-x org-capture` (or the user's capture keybinding) offers a Total Recall entry.

#### Scenario: Org-capture template is registered
- **WHEN** `total-recall-capture-init` is called with an adapter
- **THEN** `org-capture-templates` SHALL contain an entry with key "r" and description matching "Recall"

#### Scenario: User can disable auto-registration
- **WHEN** `total-recall-capture-init` is called with `:register nil`
- **THEN** the org-capture template SHALL NOT be registered

### Requirement: Capture buffer shows a structured form
The capture buffer SHALL display a set of fields with commented instructions, so the user knows what to fill in and an LLM can interpret the format.

#### Scenario: Buffer contains term and definition fields
- **WHEN** the capture template opens
- **THEN** the buffer SHALL contain `term::` and `definition::` lines

#### Scenario: Buffer contains optional fields
- **WHEN** the capture template opens
- **THEN** the buffer SHALL contain optional fields: `tags::`, `depth::`, `examples::`, `notes::`, `analogy::`, `source-lang::`, `target-lang::`, `part-of-speech::`, `prerequisites::`

#### Scenario: Buffer contains comments
- **WHEN** the capture template opens
- **THEN** the buffer SHALL contain `#`-prefixed comment lines providing field-level instructions

### Requirement: Parser converts buffer text to an item plist
The system SHALL provide a parser function that converts capture buffer text into a plist suitable for `total-recall-make-item`.

#### Scenario: Parse basic fields
- **WHEN** the buffer contains `term:: voracious\n definition:: extremely hungry`
- **THEN** the parser SHALL return `(:term "voracious" :definition "extremely hungry")`

#### Scenario: Comment lines are ignored
- **WHEN** the buffer contains `# this is a comment\n term:: foo`
- **THEN** the parser SHALL return a plist with `:term "foo"` and no `:comment` key

#### Scenario: Continuation lines are joined
- **WHEN** the buffer contains `definition:: a long\n definition that continues`
- **THEN** the parser SHALL return `:definition "a long definition that continues"`

#### Scenario: Tags parse to symbol list
- **WHEN** the buffer contains `tags:: :vocabulary :german`
- **THEN** the parser SHALL return `:tags (:vocabulary :german)`

#### Scenario: Depth parses to integer
- **WHEN** the buffer contains `depth:: 5`
- **THEN** the parser SHALL return `:depth 5`

#### Scenario: Blank fields are omitted
- **WHEN** the buffer contains `notes::\n` (empty)
- **THEN** the parser SHALL omit `:notes` from the plist

#### Scenario: Empty buffer returns nil
- **WHEN** the buffer contains only comments and whitespace
- **THEN** the parser SHALL return nil

### Requirement: Examples parse to cons cells
The examples field SHALL parse each bullet line into a cons cell `(text . props)`.

#### Scenario: Parse example with no props
- **WHEN** the buffer contains `examples::\n  - "simple text"`
- **THEN** the parser SHALL return `:examples (("simple text" . ()))`

#### Scenario: Parse example with props
- **WHEN** the buffer contains `examples::\n  - "In Python" :lang Python`
- **THEN** the parser SHALL return `:examples (("In Python" . (:lang "Python")))`

#### Scenario: Multi-line example text preserves line breaks
- **WHEN** the buffer contains `examples::\n  - "line one\n    line two" :lang Python`
- **THEN** the parser SHALL preserve the internal newline in the example text

### Requirement: Commit parses, creates, and saves
The commit function SHALL parse the buffer, create an item closure, and save it via the injected storage adapter.

#### Scenario: Commit saves item to adapter
- **WHEN** the commit function processes a valid capture buffer
- **THEN** it SHALL create an item via `total-recall-make-item`
- **AND** save it via the adapter's `:save-item` function
- **AND** return the item id

#### Scenario: Commit with empty buffer does nothing
- **WHEN** the commit function processes an empty (or comment-only) buffer
- **THEN** it SHALL NOT save anything
- **AND** it SHALL signal an error or cancel the capture

### Requirement: Tags are applied via tag module
When tags are present in the parsed capture, the commit SHALL use `total-recall-tag--add` to apply them after item creation.

#### Scenario: Tags are applied after creation
- **WHEN** a capture has tags `:vocabulary :german`
- **THEN** the item SHALL be created first
- **AND** `total-recall-tag--add` SHALL be called with those tags
- **AND** the item's `:tags` SHALL contain them
- **AND** the saved item SHALL persist tagged state

### Requirement: Adapter is injected
The capture system SHALL receive its storage adapter and configuration via a factory function, following the project's dependency injection pattern.

#### Scenario: Factory returns configured capture committer
- **WHEN** `total-recall-capture-init` is called with an adapter plist
- **THEN** it SHALL return a function that, when called, runs the complete capture flow against that adapter

### Requirement: Capture template is a `plain` org-capture type
The org-capture template SHALL use type `plain` to insert the form directly into a new buffer without wrapping it in an Org entry.

#### Scenario: Template type is plain
- **WHEN** the org-capture template is examined
- **THEN** its type SHALL be `plain`