## Context

See proposal.md for motivation. The current `total-recall-capture--parse-examples` function in `total-recall-capture.el` handles two bullet formats:
1. `- "quoted text"` — parsed as example text (with optional properties)
2. `- "multi-line text...` — opening quote activates multi-line mode

Bare/unquoted bullets (e.g., `- просто текст`) fall through to a silent skip branch and are discarded.

## Goals / Non-Goals

**Goals:**
- Add a third parse branch for unquoted bullet lines in `total-recall-capture--parse-examples`
- For unquoted bullets, treat the bare text as a plain example with no properties
- All existing formats (quoted, quoted-with-props, multi-line quoted) continue to work unchanged

**Non-Goals:**
- No changes to storage, serialization, item model, or training display
- No changes to the org-capture template or user-facing format
- No support for properties on unquoted bullets (that's what the quoted format is for)

## Decisions

### Decision: Add a case-3 branch rather than refactoring the parser
The existing parser has three cases ordered by a nested if/if/else. Adding a fourth else-branch (fallback: treat as plain text) is the minimal change with zero risk to existing paths.

**Alternatives considered:**
- Refactor to a data-driven dispatch: unnecessary complexity for a two-case extension
- Require quotes: defeats the purpose — the whole motivation is supporting unquoted input

### Decision: Unquoted text after `- ` is the entire example with no props
If users want properties on an example, they must use the quoted format (`- "text" :key val`). This avoids ambiguity: without quotes, there's no clear delimiter between text and property tokens.

## Risks / Trade-offs

- **Leading/trailing whitespace in unquoted text**: `string-trim` is already applied to the overall field value. The bullet regex `[ \t]*-[ \t]+\(.*\)` captures everything after `- `, so leading spaces within the text are preserved. Trailing whitespace is minimal risk since capture buffers are typically newline-terminated.
- **Accidental parsing of non-example content**: The parser already skips lines before any field header, and only processes bullets inside the `examples::` field. Risk is negligible.