## Why

The package cannot be installed via `use-package` with `:straight` because there is no `total-recall.el` entry point file. Emacs package management requires a main library file matching the package name that provides the package feature. Currently, each module is distributed across separate files (`total-recall-item.el`, `total-recall-sched.el`, etc.) with no central entry point to load them all.

## What Changes

- Create `total-recall.el` — a minimal entry point file in the repository root that:
  - Provides the `total-recall` feature via `(provide 'total-recall)`
  - Loads all sub-modules in dependency order
  - Carries a `;;; Commentary:`, `;;; Code:`, and standard header
- No behavioral or API changes to any existing module

## Capabilities

### New Capabilities

None — this is a pure packaging/tooling change. The `skip_specs: true` flag is set in the change's `.openspec.yaml` because there are no spec-level behavior changes.

### Modified Capabilities

None — no existing behaviors or requirements are changing.

## Impact

- **Added file**: `total-recall.el` in the repository root
- **Existing files**: None modified — all existing `.el` files remain unchanged
- **Dependencies**: None new — simply loads existing modules