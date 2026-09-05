# Item Model Specification

## Purpose

Defines the unified data structure for memorization items — the shape, creation, read/write operations, and serialization contract for any flashcard-like entry (vocabulary, technical terms, concepts, etc.).

## Requirements

### Requirement: Item has required fields
Every item SHALL have `:id`, `:term`, `:definition`, `:tags`, `:depth`, `:created`, and `:modified`.

#### Scenario: New item has all required fields
- **WHEN** a new item is created with a term and a definition
- **THEN** the item SHALL have `:id` set to a non-nil string
- **AND** `:term` SHALL equal the provided term
- **AND** `:definition` SHALL equal the provided definition
- **AND** `:tags` SHALL be an empty list
- **AND** `:depth` SHALL be 3
- **AND** `:created` SHALL be a non-nil string (ISO-8601 timestamp)
- **AND** `:modified` SHALL equal `:created`

#### Scenario: Create item with optional fields
- **WHEN** a new item is created with a term, definition, and an alist of optional fields
- **THEN** the item SHALL contain those optional fields

### Requirement: Item supports optional fields
An item MAY have any of: `:source-lang`, `:target-lang`, `:part-of-speech`, `:examples`, `:analogy`, `:notes`, `:prerequisites`.

#### Scenario: Optional fields are present when set
- **WHEN** an item is created with `:examples` and `:analogy`
- **THEN** `(item 'get :examples)` SHALL return the provided examples
- **AND** `(item 'get :analogy)` SHALL return the provided analogy

### Requirement: Item supports get operation
An item SHALL respond to the `'get` command by returning the value of the given key.

#### Scenario: Get existing key
- **WHEN** `(item 'get :term)` is called on an item with term "voracious"
- **THEN** it SHALL return "voracious"

#### Scenario: Get missing key
- **WHEN** `(item 'get :nonexistent)` is called
- **THEN** it SHALL return nil

### Requirement: Item supports set operation
An item SHALL respond to the `'set` command by updating the value of the given key and updating `:modified`.

#### Scenario: Set existing key
- **WHEN** `(item 'set :definition "new def")` is called
- **THEN** `(item 'get :definition)` SHALL equal "new def"
- **AND** `(item 'get :modified)` SHALL be updated to a later timestamp

#### Scenario: Set new key
- **WHEN** `(item 'set :notes "some notes")` is called on an item without `:notes`
- **THEN** `(item 'get :notes)` SHALL equal "some notes"

### Requirement: Item supports serialize operation
An item SHALL respond to the `'serialize` command by returning the raw data plist.

#### Scenario: Serialize returns complete plist
- **WHEN** `(item 'serialize)` is called
- **THEN** it SHALL return a plist containing all keys and values of the item
- **AND** the plist SHALL be a valid argument to `json-encode`

#### Scenario: Serialized plist round-trips through make-item
- **WHEN** an item is serialized and a new item is created from that plist
- **THEN** the new item SHALL have the same values for all keys as the original

### Requirement: Item examples are a list of (text . props) pairs
The `:examples` field SHALL be a list where each element is a cons cell `(text . props)` where `text` is a string and `props` is a plist.

#### Scenario: Add example to item
- **WHEN** `(item 'set :examples '(("In Python: injection via args" . (:lang "Python"))))`
- **THEN** `(item 'get :examples)` SHALL return the list with one example
- **AND** `(car (car (item 'get :examples)))` SHALL be "In Python: injection via args"

### Requirement: Item id is generated automatically
The item factory SHALL generate a unique id if none is provided.

#### Scenario: Generated id is a string
- **WHEN** a new item is created without an `:id`
- **THEN** `(item 'get :id)` SHALL be a non-nil string matching the format `TIMESTAMP-RANDOM`

#### Scenario: Provided id is kept
- **WHEN** a new item is created with `:id "my-custom-id"`
- **THEN** `(item 'get :id)` SHALL equal "my-custom-id"