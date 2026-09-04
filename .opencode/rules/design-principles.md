## Design Rules for Emacs Lisp (plain `defun`)

No `cl-defstruct`, `cl-defgeneric`, `cl-defmethod`, or classes. Use plain functions, arguments, closures, and higher-order functions.
**Testability is the quality signal**: if an ERT test is hard to write, the design is wrong.

---

### 1. Core Philosophy

- **Behavior, not implementation** — tests specify the contract, not internal workings.
- **Test-first as design practice** — write the test before the function.
- **Easy arrange = good design** — setup should be 1–3 lines. If it needs `cl-letf` or `advice-add`, refactor.

### 2. Dependency Injection

Pass dependencies as function arguments. Never hardcode external calls (HTTP, DB, etc.) inside a function.

### 3. Factories as Composition Roots

Factory reads config once, returns a configured function. Intermediate layers never see raw config.

### 4. Protocols via Docstrings & Duck Typing

Document the expected call signature in the docstring. Any function satisfying it is a valid dependency.

### 5. Interfaces for Third-Party Libs

Wrap external libraries behind your own adapter functions. Domain code never calls the library directly.

### 6. Composition Over Inheritance

Use higher-order functions to compose small pieces. Each piece is independently testable.

### 7. Rich Domain Models (closures)

Encapsulate data + behavior via closures (a "model" is a function that closes over its data and dispatches on a method keyword).

### 8. Readability Guards

- No magic numbers — centralize config in a plist/alist.
- No premature optimization — write clean code first, profile later.

### 9. When to Inject vs. Relax

| Dependency | Verdict | Idiom |
|---|---|---|
| HTTP calls | INJECT | Function arg |
| Database sessions | INJECT | Function arg |
| API keys | INJECT via factory | Read once, pass configured fn |
| Third-party libs | INJECT via adapter | Write wrapper, inject wrapper |
| `current-time` | CONTEXT-DEPENDENT | Inject if output-shaping; else use directly |
| Configuration | INJECT via factory | Factory reads config, returns configured fn |
| Logging (`message`) | DON'T INJECT | Use directly — it's observability |
| File paths (`expand-file-name`) | DON'T INJECT | Use `tmp-dir` in tests; overkill to abstract |

### 10. Anti-Patterns

| Anti-pattern | How to avoid |
|---|---|
| God functions | Too many args → testability forces splitting |
| Circular dependencies | Can't construct a test → break the cycle |
| Global mutable state | Inject state as arg or closure |
| `advice-add` as norm | Signals missing injection point — fix design, not test |
| Anemic data + utility functions | Data and operations belong together (closures) |
| Implementation-coupled tests | Test-first + behavior focus prevent them |