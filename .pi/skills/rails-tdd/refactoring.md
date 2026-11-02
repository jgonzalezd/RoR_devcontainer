# Refactor Candidates (post-green)

After getting green, scan for high-value cleanup:

- **Duplication** -> extract shared method/object
- **Long methods** -> split into intention-revealing helpers
- **Feature envy** -> move logic closer to owned data
- **Primitive obsession** -> introduce value objects
- **Leaky controllers** -> move business rules to domain layer
- **Shallow interfaces** -> deepen modules, reduce public surface

## Guardrails

- Keep behavior stable; rerun tests after each refactor step.
- Prefer a sequence of tiny safe refactors over one big rewrite.
- If refactor alters behavior, write/adjust tests first (new red step).
