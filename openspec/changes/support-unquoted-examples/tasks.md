## 1. Tests (RED)

- [x] 1.1 Add ERT test `test-capture-parse-example-unquoted` to `tests/test-capture.el` that asserts `examples::\n  - просто текст` parses to `:examples (("просто текст" . ()))`. Run the test and confirm it **fails** (RED phase of TDD).
- [x] 1.2 Add ERT test `test-capture-parse-example-mixed-quoted-unquoted` to `tests/test-capture.el` that asserts a mix of quoted and unquoted bullets are both parsed correctly. Run the test and confirm it **fails** (RED phase).

## 2. Parser Implementation (GREEN)

- [x] 2.1 Add an unquoted-text branch to `total-recall-capture--parse-examples` in `total-recall-capture.el`: when a bullet line has bare text (no opening `"`), treat the captured text as a plain example with no properties. Run both tests from task 1 and confirm they **pass** (GREEN phase).

## 3. Verify existing tests still pass

- [x] 3.1 Run the full ERT test suite and confirm all existing tests still pass alongside the new ones (regression check).