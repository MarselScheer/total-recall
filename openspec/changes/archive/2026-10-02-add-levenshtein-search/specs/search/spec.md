# Search Specification

## Purpose

Provides a lightweight fuzzy search that finds memorization items whose terms most closely match a given input word, using Levenshtein distance as the similarity metric.

## ADDED Requirements

### Requirement: Search by word at point

The system SHALL provide an interactive command `total-recall-search` that grabs the word at point from the current Emacs buffer and searches all item terms for the closest matches using Levenshtein distance.

#### Scenario: Word at point matches a term exactly
- **WHEN** the word at point is "voracious" and an item exists with term "voracious"
- **THEN** that item SHALL appear as the first result with distance 0

#### Scenario: Word at point matches nothing
- **WHEN** the word at point is "zzzzzzz" and no item term has a Levenshtein distance below a usable range
- **THEN** the command SHALL display a message indicating no close matches were found

#### Scenario: No word at point
- **WHEN** the buffer is empty or point is not on a word
- **THEN** the command SHALL display a message explaining that no word was found at point

### Requirement: Results ordered by Levenshtein distance

The search results SHALL be sorted by ascending Levenshtein distance, so the most similar terms appear first.

#### Scenario: Closest match appears first
- **WHEN** the search term is "храбрый" and items exist with terms "храбрость" (dist 4), "храбрец" (dist 5), and "слабость" (dist 8)
- **THEN** "храбрость" SHALL appear first, followed by "храбрец", followed by "слабость"

#### Scenario: Exact match is always first
- **WHEN** the search term is "voracious" and items exist with terms "voracious" and "voraciously"
- **THEN** "voracious" SHALL appear first with distance 0

### Requirement: Configurable result count

The number of results displayed SHALL be configurable via a user option `total-recall-search-count`.

#### Scenario: Default result count is 5
- **WHEN** the user runs `total-recall-search` without customizing the option
- **THEN** at most 5 results SHALL be displayed

#### Scenario: Custom result count
- **WHEN** `total-recall-search-count` is set to 10
- **THEN** at most 10 results SHALL be displayed

### Requirement: Results display term and definition

Each result in the minibuffer SHALL show the item's term, the Levenshtein distance, and the item's definition.

#### Scenario: Result line format
- **WHEN** search results are displayed
- **THEN** each result SHALL show the term, distance, and definition in a readable format
- **AND** the definition SHALL be truncated to a reasonable length for minibuffer display

### Requirement: Search is non-destructive

The search command SHALL not modify any item data, schedule data, or storage state.

#### Scenario: Search does not alter storage
- **WHEN** the user runs `total-recall-search`
- **THEN** no items SHALL be created, modified, or deleted
- **AND** no schedule records SHALL be created, modified, or deleted