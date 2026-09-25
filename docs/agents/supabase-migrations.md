# Supabase migrations

## Repository boundary

- `supabase/config.toml` must keep `project_id = "schooldesk-local"`. Local reset scripts assert this value and use only the synthetic Docker project.
- Use the repository-pinned Supabase CLI version, `2.116.0`, for repeatable migration commands.
- Migration identity is its timestamp/version prefix. Keep already-applied SQL files immutable; make corrections in a new forward migration.
- Never use `migration repair`, `--include-all`, or a production `db push` to make version lists appear aligned. First establish the actual schema state and review the exact pending versions.

## Create and verify a migration locally

1. Create a new migration:

   ```sh
   npx --yes --package=supabase@2.116.0 supabase migration new <descriptive_name>
   ```

2. Edit only the new migration. Review destructive DDL, data backfills, RLS, grants, foreign keys, indexes, and rollback implications.
3. Reset only the approved synthetic local project and run the applicable Docker/API checks:

   ```sh
   scripts/local_supabase.sh reset
   npx --yes --package=supabase@2.116.0 supabase migration list --local
   ```

   `migration list --local` must show every checked-in version applied locally. The local reset must replay the complete migration chain and both synthetic seed files without editing hosted history.

## Compare and promote to production

Production commands are separate from `scripts/local_supabase.sh`. Confirm the explicit production ref before linking or running any hosted command:

```sh
npx --yes --package=supabase@2.116.0 supabase link --project-ref qzdhymlabzqjeocetqqv
npx --yes --package=supabase@2.116.0 supabase migration list --linked
npx --yes --package=supabase@2.116.0 supabase db push --dry-run --linked
```

Before a real push, check that the dry run lists only the reviewed new migration versions, compare the proposed schema effect with the live catalog, confirm backups/rollback steps, and finish the local Docker and applicable device gates. Do not proceed if any unexpected migration is pending. Then apply only the reviewed migration using the approved production workflow and verify its catalog postconditions.

After those gates pass, apply the reviewed pending migration with:

```sh
npx --yes --package=supabase@2.116.0 supabase db push --linked
```

The working tree may not have a CLI project link. Linking is an explicit hosted-project operation and should only be done when a production comparison or promotion is intended. Do not change `supabase/config.toml` to the production ref.

## Historical records

Some existing production migration names differ from the checked-in filenames even though their version IDs match. Nine historical files named `remote_applied_schema_marker` preserve version history where the original hosted SQL was unavailable. Do not rename these or invent replacement SQL based on the production display name. Current migration-list parity is based on version IDs; catalog comparison documents any remaining runtime differences separately.
