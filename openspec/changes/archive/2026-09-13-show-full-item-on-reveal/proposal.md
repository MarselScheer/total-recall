## Why

During training, only the term and definition are shown even after revealing the answer. Users miss out on rich context from examples, notes, analogies, tags, and depth — plus schedule metadata like repetitions, last-review, and lapses. Showing all item information on reveal makes training more effective and lets users reinforce understanding through the full material.

## What Changes

- When the user reveals the answer during training, all item fields are displayed: the answer, tags, depth, examples, notes, and analogy (where non-nil)
- Schedule metadata for the current direction (repetitions, last-review, lapses) is also displayed on reveal
- Examples, notes, and analogy are rendered with distinct colors for visual distinction
- Color for each field is configurable via customizable faces
- Nil/empty fields are gracefully omitted from the display

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `training`: The card rendering on answer reveal is extended to display all item fields (tags, depth, examples, notes, analogy) and the current direction's schedule metadata (repetitions, last-review, lapses) — with distinct faces for examples, notes, and analogy.

## Impact

- `total-recall-train.el`: The `total-recall-train--render-card` function is the primary change point. It currently renders only prompt and answer. On reveal it will additionally render all non-nil item fields and the current schedule's metadata.
- New faces defined: `total-recall-train-examples-face`, `total-recall-train-notes-face`, `total-recall-train-analogy-face` for colored display of those fields.
- `total-recall-train--render-card` will load the schedule via the adapter to show `:repetitions`, `:last-review`, `:lapses` for the current direction.
- The session state already carries `:adapter`, so schedule loading is possible.