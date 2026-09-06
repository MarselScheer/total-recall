## Context

See `proposal.md — Why` for motivation. The package has five standalone modules
(`total-recall-item.el`, `total-recall-tags.el`, `total-recall-sched.el`,
`total-recall-storage.el`, `total-recall-capture.el`) but no entry point that
loads them together.  `use-package` with `:straight` requires a library file
matching the package name that `provide`s the feature.

## Goals / Non-Goals

**Goals:**
- Create `total-recall.el` as the single entry point for the package
- Load all sub-modules in correct dependency order
- Emit `(provide 'total-recall)` so `(featurep 'total-recall)` returns `t`
- Carry standard file header, Commentary, Code, and footer boilerplate

**Non-Goals:**
- No behavioral or API changes to any existing module
- No new functionality, no new dependencies
- No changes to `openspec/` directory or test files

## Decisions

| Decision | Rationale | Alternatives Considered |
|---|---|---|
| **Single `total-recall.el` at repo root** | Matches Emacs package convention (file name = feature name). straight.el resolves `:repo "MarselScheer/total-recall"` by looking for `total-recall.el` in the repo root. | Placing it under `lisp/` would break straight.el's default heuristic. |
| **Dependency order: item → tags → sched → storage → capture** | Each module `require`s only modules it depends on; loading them bottom-up avoids forward-reference warnings. item has no deps, tags depends on item, sched depends on item, storage depends on item + sched, capture depends on item + tags. | Alphabetical order would work but hides intent. |
| **No custom `:init` or `:config` code in `total-recall.el`** | The package follows a DI pattern — the user must init the storage adapter and capture factory themselves. Putting a canned init in the entry point would couple the module to a default config and contradict the project's design rules. | Adding an `:init` function was considered but rejected — it would create a global state footgun. |

## Risks / Trade-offs

| Risk | Mitigation |
|---|---|
| **Circular dependency if a future module requires `total-recall`** | Each module `require`s only its direct dependencies, never the umbrella feature. Enforce this in code review. |
| **User forgets to call `total-recall-capture-init` and gets no capture template** | Document the required `:config` block in the README. The `:register` default handles template registration when init is called. |