## Purpose

Defines how tags organize memorization items — tags are the single cross-cutting dimension for grouping, filtering, and categorizing items across any domain.

## ADDED Requirements

### Requirement: Tags are stored as a list of symbols
Every item SHALL have a `:tags` field that is a list of symbols (e.g., `(:vocabulary :german :beginner)`).

#### Scenario: Tag list is empty by default
- **WHEN** a new item is created
- **THEN** `(item 'get :tags)` SHALL be nil

#### Scenario: Tags are symbols
- **WHEN** an item has tags
- **THEN** every element of the tags list SHALL satisfy `symbolp`

### Requirement: Tags can be added to an item
The system SHALL provide a function to add one or more tags to an item.

#### Scenario: Add single tag
- **WHEN** a tag is added to an item
- **THEN** the item's `:tags` SHALL include that tag

#### Scenario: Add multiple tags
- **WHEN** multiple tags are added to an item at once
- **THEN** the item's `:tags` SHALL include all of them

#### Scenario: Adding duplicate tag is idempotent
- **WHEN** a tag that already exists on the item is added again
- **THEN** the item's `:tags` SHALL not contain duplicates

### Requirement: Tags can be removed from an item
The system SHALL provide a function to remove one or more tags from an item.

#### Scenario: Remove existing tag
- **WHEN** a tag is removed from an item that has it
- **THEN** the item's `:tags` SHALL not include that tag

#### Scenario: Remove non-existent tag
- **WHEN** a tag that is not on the item is removed
- **THEN** the item's `:tags` SHALL remain unchanged

### Requirement: Items can be queried by tag
The system SHALL support querying all items that have a given tag.

#### Scenario: Query items by tag returns matching items
- **WHEN** items are queried by tag `:german`
- **THEN** the result SHALL include all items that have `:german` in their `:tags`

#### Scenario: Query by tag with no matches
- **WHEN** items are queried by a tag that no item has
- **THEN** the result SHALL be an empty list

### Requirement: All available tags can be listed
The system SHALL provide a function to return every distinct tag that exists across all items.

#### Scenario: List all tags returns union of all tags
- **WHEN** items exist with tags `:german`, `:vocabulary`, and `:beginner`
- **THEN** the list of all available tags SHALL contain `:german`, `:vocabulary`, and `:beginner`

#### Scenario: Duplicate tags across items are collapsed
- **WHEN** multiple items have the tag `:german`
- **THEN** the list of all available tags SHALL contain `:german` only once

#### Scenario: List all tags when no tags exist
- **WHEN** no items have any tags
- **THEN** the list of all available tags SHALL be nil

### Requirement: Tags are persisted with the item
Tags SHALL be stored and loaded from the database as part of the item.

#### Scenario: Tags survive save and load cycle
- **WHEN** an item with tags is saved to the database and loaded back
- **THEN** `(item 'get :tags)` SHALL equal the original tags