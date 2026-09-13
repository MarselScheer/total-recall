## Why

When capturing memorization items, users naturally write examples as an indented dash-list with bare text (e.g., `  - Пить водУ нужно чИстой.`), but the parser only recognizes quoted-text bullets (`- "text"`). Unquoted bullets are silently skipped and never persisted, making the examples field silently non-functional for the most intuitive input format.

## What Changes

- Add unquoted-bullet support to `total-recall-capture--parse-examples`: when a bullet line has bare text (no opening `"`), treat it as a plain example with no properties
- Update the existing capture spec to include a scenario for unquoted bullets
- No breaking changes — quoted bullets with optional props continue to work exactly as before

## Capabilities

### New Capabilities

*None.*

### Modified Capabilities

- `capture`: Add support for unquoted bullet text in the examples field parser

## Impact

- **`total-recall-capture.el`**: ~5 line change in `total-recall-capture--parse-examples` to add a new parse branch for unquoted bullets
- **`tests/test-capture.el`**: Add test cases for unquoted examples
- No schema, storage, or API changes