# Change manifest: {{TASK_ID}}

- Commit range: `{{BASE}}..{{HEAD}}`
- Commits:
{{COMMITS}}

Studio is the source of truth. `src/` is a snapshot exported from Studio after testing. Each diff below is that snapshot's change.

## Added
| File | Purpose |
|---|---|
{{ADDED}}

## Changed
| File | What changed and why |
|---|---|
{{CHANGED}}

## Removed
| File | Why |
|---|---|
{{REMOVED}}

## Docs updated
{{DOCS}}

## Studio-only changes (not in src/)
{{World geometry, place settings or other Studio changes that aren't scripts. "None" if none.}}

## Configuration values introduced or changed
| Setting | Old | New | Where |
|---|---|---|---|
{{CONFIG}}
