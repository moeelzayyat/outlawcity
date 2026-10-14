# OUTLAW CITY — agent notes

- Edit code in the live Studio place through the Roblox Studio MCP. No Rojo. `src/` is a snapshot only; re-export it after a tested milestone.
- Read `docs/ARCHITECTURE.md` before changing anything; follow its naming, boot order, network contract and security rules.
- Only the primary integration agent edits Studio; other agents hand off files (see `docs/AGENTS.md`).
- Inspect before editing, one major system at a time, never delete working systems without owner approval.
- Unit tests run automatically at the start of each Studio playtest (`[Tests] N passed, 0 failed`). Add a `*.spec` in `ServerStorage.Tests` for new pure logic.
- Nothing counts as working until a Studio playtest passes. Update `docs/PROGRESS.md` (completed, known issues, upcoming) after each change.
- Gotcha: the Studio MCP resets `Camera.CameraType` after `execute_luau` runs in the client, so don't treat that as a game bug.
- Ask the owner before starting work beyond the approved stage (see `docs/PROGRESS.md` → Upcoming). The owner saves a backup (cloud + `OutlawCity_<stage>.rbxl`) before each stage; check the Studio log for "Place file downloaded".
- Keep VehicleValidationService monitor-only and NPC police at one unit unless the owner approves otherwise.
- After every substantial completed task, build an auditor package in `docs/audits/<task-id>/` (see `docs/audits/README.md`), give the owner a ready-to-paste auditor prompt (`00_AUDITOR_PROMPT.md`; the auditor is an AI agent) plus the exact list of edited .md files to upload (no ZIP), and wait for approval before the next significant batch. Audit evidence must come only from Outlaw City (placeId 132163592957463); another Roblox game may be open.
