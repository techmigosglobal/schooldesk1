# Domain docs

This repository uses a single-context layout for domain knowledge and architecture decisions.

## Before exploring

- Read the root `CONTEXT.md` when it exists. If a `CONTEXT-MAP.md` is added later, use it to locate context documents relevant to the work.
- Read the relevant records in `docs/adr/` when they exist.
- If these files are absent, proceed without calling out their absence or creating them upfront. Create domain documentation when a domain-modeling task resolves terminology or a lasting decision.

## Vocabulary

Use terms as defined in `CONTEXT.md` in issue titles, code, tests, and design notes. If a needed term is missing, identify it as a domain-modeling gap rather than inventing a synonym.

## Architecture decisions

Surface conflicts with existing ADRs instead of silently replacing their decisions. Add new ADRs under `docs/adr/` when a decision needs a durable record.
