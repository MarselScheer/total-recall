## 1. Faces and rendering infrastructure

- [ ] 1.1 Write ERT tests for the new faces and the `total-recall-train--render-field` helper, then implement them: define three new faces (`total-recall-train-examples-face`, `total-recall-train-notes-face`, `total-recall-train-analogy-face`) with distinct default colors using `defface`, and add a helper `total-recall-train--render-field` that inserts a labeled section with an optional face. Verify faces are available via `facep` and the helper inserts headings, applies faces, and skips nil values.

## 2. Extended reveal rendering

- [ ] 2.1 Write ERT tests first for schedule metadata display on reveal (create item, simulate reveal, assert `:repetitions`, `:last-review`, `:lapses` appear), then modify `total-recall-train--render-card` to load the current direction's schedule via the adapter and render its metadata. Verify existing rendering tests still pass.
- [ ] 2.2 Write ERT tests first for all item fields appearing on reveal (create item with `:tags`, `:depth`, `:examples`, `:notes`, `:analogy`, simulate reveal, assert each appears with its heading and that nil fields are omitted), then extend `total-recall-train--render-card` to render all non-nil item fields on reveal with `:examples` using `total-recall-train-examples-face`, `:notes` using `total-recall-train-notes-face`, and `:analogy` using `total-recall-train-analogy-face`. Verify tests pass.

## 3. Verify and cleanup

- [ ] 3.1 Run the full test suite (`ert t`) and confirm all existing and new tests pass.