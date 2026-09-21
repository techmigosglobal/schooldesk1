## Agent skills

### Issue tracker

Issues and specs for this repository live in GitHub Issues. Use the `gh` CLI and follow `docs/agents/issue-tracker.md`. External issue changes require explicit authorization in the current request.

### Triage labels

Use `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, and `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Treat this as a single-context repository. Read the root `CONTEXT.md` and relevant decisions in `docs/adr/` when they exist. See `docs/agents/domain.md`.

### Supabase migrations

Keep Docker-local migration workflow separate from hosted commands. Use the pinned CLI and follow `docs/agents/supabase-migrations.md` for migration creation, local reset, production history comparison, dry-run review, and promotion safeguards.
