## 1. Edit Mode and Buffer

- [ ] 1.1 Create `total-recall-edit-mode` as a derived mode with `C-c C-c` (commit) and `C-c C-k` (cancel) keybindings, and verify the mode map is set up correctly in an ERT test
- [ ] 1.2 Implement a pre-fill function that takes an item closure and returns a `key:: value` string for editable fields (term, definition, tags, depth, examples, notes, analogy), and verify the output format matches the capture template format in tests
- [ ] 1.3 Implement the edit buffer opening logic that creates a buffer named `*total-recall-edit*`, sets buffer-local variables for the original item plist, adapter, and return buffer, inserts pre-filled content, and enters `total-recall-edit-mode`; verify with a test that the buffer opens with the correct content

## 2. Commit and Cancel

- [ ] 2.1 Implement the commit command: parse the edit buffer with `total-recall-capture--parse`, validate term and definition are non-nil (error otherwise), merge parsed fields over the original plist (keeping original `:id` and `:created`), create a new item via `total-recall-make-item`, save via the adapter, and kill the edit buffer; verify with an ERT test that modified item data is persisted
- [ ] 2.2 Verify the commit command preserves `:id` and `:created` from the original item in an ERT test
- [ ] 2.3 Verify that editing an item does not modify its schedule records (forward or backward) in an ERT test
- [ ] 2.4 Implement the cancel command: kill the edit buffer without saving and switch back to the return buffer; verify with an ERT test that item data is unchanged

## 3. Training Integration

- [ ] 3.1 Add `E` to `total-recall-train-mode-map` bound to a new `total-recall-train-edit` command that: (a) does nothing when the answer is hidden, (b) when answer is revealed, loads the current item from the adapter, opens the edit buffer with pre-filled data, and stores buffer-local state for the return flow; verify with ERT tests for both guard states
- [ ] 3.2 After commit, switch back to the training buffer, re-load the item from storage, update the session state's `:current` item, and call `total-recall-train--render` to display the updated data; verify the training display reflects the changes in an integration test