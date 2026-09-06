## 1. Test file and module scaffold (TDD: write tests, check they fail, then minimal implementation, then refactor)

- [x] 1.1 Create `tests/test-capture.el` with the ERT boilerplate, module requires, and capture-tests prefix — verify it loads without errors via `emacs --batch -l tests/test-capture.el`
- [x] 1.2 Create `total-recall-capture.el` with the module header, `(provide 'total-recall-capture)` and the `total-recall-capture-init` function stub that returns a no-op lambda — verify `(require 'total-recall-capture)` succeeds and `(funcall (total-recall-capture-init nil))` returns nil

## 2. Parser implementation (TDD: write tests, check they fail, then minimal implementation, then refactor)

- [ ] 2.1 Implement `total-recall-capture--parse` as a pure function: strip `;;` comment lines, parse `key:: value` pairs, join indented continuation lines, omit blank fields, return nil for empty/comment-only input — verify the `test-capture.el` basic-fields, comments-ignored, continuation-lines, blank-fields-omitted, and empty-buffer scenarios pass
- [ ] 2.2 Add tag parsing: split space-separated `:keyword` tokens in the `tags::` value, intern each to a symbol — verify the tags-parse-to-symbol-list scenario passes
- [ ] 2.3 Add numeric parsing: parse `depth::` values as integers — verify the depth-parses-to-integer scenario passes
- [ ] 2.4 Add example parsing: parse bullet lines under `examples::` with quoted-string text and optional `:key val` props into cons cells `("text" . (:key "val"))`, supporting multi-line example text — verify the single-example, props-example, and multi-line-example scenarios pass

## 3. Commit and factory (TDD: write tests, check they fail, then minimal implementation, then refactor)

- [ ] 3.1 Implement `total-recall-capture--commit`: receives a buffer string, calls `--parse`, creates item via `total-recall-make-item`, applies tags via `total-recall-tag--add`, saves via `:save-item` on the injected adapter, returns the item id — verify the commit-saves-item scenario passes against an in-memory SQLite adapter
- [ ] 3.2 Implement `total-recall-capture-init`: accepts a storage adapter plist and an optional `:register` keyword, returns a configured closure that runs `--commit`; when `:register` is non-nil (or absent), add an org-capture template entry with key "r" and description "Recall"; when nil, skip registration — verify the factory returns a function, and that registration/no-registration behave per spec scenarios
- [ ] 3.3 Wire `:before-finalize` on the org-capture template: set up the capture template's `:before-finalize-hook` to call the configured commit function with the buffer content, then kill the buffer — verify an end-to-end test passes

## 4. Integration and verification (TDD: write tests, check they fail, then minimal implementation, then refactor)

- [ ] 4.1 Write an end-to-end test: init storage with `:memory:`, init capture factory, simulate a full capture cycle (buffer text → item in DB), load the item back and verify all fields including tags and examples — verify the test passes
- [ ] 4.2 Run the full test suite with `mise run test` and confirm no regressions in existing tests
- [ ] 4.3 Manual verification: open a capture buffer, fill in term/definition/tags, save, and confirm the item appears in the database via `:query-all`
