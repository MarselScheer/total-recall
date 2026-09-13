## MODIFIED Requirements

### Requirement: Examples parse to cons cells
The examples field SHALL parse each bullet line into a cons cell `(text . props)`.

#### Scenario: Parse example with no props `[SC-2026-09-13_08-01-06-01]`
- **WHEN** the buffer contains `examples::\n  - "simple text"`
- **THEN** the parser SHALL return `:examples (("simple text" . ()))`

#### Scenario: Parse example with props `[SC-2026-09-13_08-01-06-02]`
- **WHEN** the buffer contains `examples::\n  - "In Python" :lang Python :version 2`
- **THEN** the parser SHALL return `:examples (("In Python" . (:lang "Python" :version "2")))`

#### Scenario: Multi-line example text preserves line breaks `[SC-2026-09-13_08-01-06-03]`
- **WHEN** the buffer contains `examples::\n  - "\nclass A:\n    a: int = 20" :lang Python`
- **THEN** the parser SHALL return `:examples (("\nclass A:\n    a: int = 20" . (:lang "Python")))`

#### Scenario: Unquoted bullet text is parsed as example with no props `[SC-2026-09-13_08-01-06-04]`
- **WHEN** the buffer contains `examples::\n  - просто текст`
- **THEN** the parser SHALL return `:examples (("просто текст" . ()))`