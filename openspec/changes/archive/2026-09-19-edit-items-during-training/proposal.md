## Why

Once an item is captured and persisted, there's no way to edit its content. Users inevitably notice typos, want to improve definitions, or add missed examples — and the training buffer is exactly where that need surfaces (seeing the card prompts "that definition could be clearer"). Currently the only recourse is to delete and re-capture.

## What Changes

- Add an `E` keybinding (`e` is too close to `w`) to the training buffer that opens an edit buffer pre-filled with the current card's data in capture-template format (`key:: value` lines)
- The edit buffer reuses the same `key:: value` parser from capture (`total-recall-capture--parse`)
- On commit (`C-c C-c`): parse the buffer, merge with the original item (preserving `:id` and `:created`), save via the storage adapter, and re-render the training buffer with updated data
- On cancel (`C-c C-k`): kill the edit buffer, return to training unchanged
- No changes to the storage schema, item model, or capture flow — only the training UI gets new functionality
- `E` is only active when the answer is revealed (same guard as `c`/`w`)

## Capabilities

### New Capabilities

*None.*

### Modified Capabilities

- `training`: Add a new edit action available during training sessions. The training spec gains requirements for the edit keybinding, the edit buffer format, and the commit/cancel flow.

## Impact

- **`total-recall-train.el`**: New `total-recall-train-edit` command, edit buffer implementation, `E` keybinding in `total-recall-train-mode-map`
- **`tests/test-train.el`**: Test scenarios for the edit flow (buffer pre-filled, commit persists, cancel aborts, fields merge correctly)