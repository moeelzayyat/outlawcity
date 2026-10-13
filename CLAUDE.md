# OUTLAW CITY — agent notes

- Edit code in the live Studio place through the Roblox Studio MCP. No Rojo. `src/` is a snapshot only; re-export it after a tested milestone.
- Read `docs/ARCHITECTURE.md` before changing anything; follow its naming, boot order, network contract and security rules.
- Only the primary integration agent edits Studio; other agents hand off files (see `docs/AGENTS.md`).
- Inspect before editing, one major system at a time, never delete working systems without owner approval.
- Unit tests run automatically at the start of each Studio playtest (`[Tests] N passed, 0 failed`). Add a `*.spec` in `ServerStorage.Tests` for new pure logic.
- Nothing counts as working until a Studio playtest passes. Update `docs/PROGRESS.md` (completed, known issues, upcoming) after each change.
- Gotcha: the Studio MCP resets `Camera.CameraType` after `execute_luau` runs in the client, so don't treat that as a game bug.
- Ask the owner before starting work beyond the approved phase (currently Phase 2).
