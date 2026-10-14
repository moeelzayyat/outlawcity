# Independent auditor workflow

ChatGPT ("The Architect") independently audits the work. After every substantial completed task, Claude builds an audit package and tells the owner exactly which files to upload. The next significant implementation batch waits for the owner's approval.

## When a package is required

- A phase or sub-phase is finished (for example 4C), or a follow-up batch of fixes.
- Any change to money, persistence, purchases, security rules or the network contract, however small.
- Docs-only or tooling-only changes (like setting up this workflow) don't need a package. They are listed in the next package's change manifest.

## What a package contains

```
docs/audits/<task-id>/
  AUDITOR_REPORT.md      what was asked, what was built, how it works, decisions, risks
  CHANGE_MANIFEST.md     commit range, every file added/changed/removed and why
  TEST_EVIDENCE.md       every test with its exact result (pass, fail or not run)
  AUDITOR_QUESTIONS.md   specific questions the auditor should answer
  00_AUDITOR_PROMPT.md   the prompt the owner pastes to the auditor (an AI agent)
  diffs/                 one .diff per changed source file + ALL.diff (git, base..head)
  screenshots/           evidence images, each listed in TEST_EVIDENCE.md
```

`<task-id>` is `YYYY-MM-DD_<short-name>`, for example `2026-10-14_phase-4C`.

The templates are in `docs/audits/templates/`. `00_AUDITOR_PROMPT.md` is the prompt the owner pastes to the auditor. No ZIP (auditor's preference, 2026-10-14): the owner uploads the edited Markdown files listed in the handoff. Fill in the task summary and task-specific constraints. Fill every section. Write "None" or "Not tested" rather than deleting a section, so the auditor can see that nothing was skipped silently.

## Evidence rules

- **Only our game.** All evidence must come from **OUTLAW CITY, place ID 132163592957463**. Another Roblox game may be open on the owner's PC.
  - Before capturing anything, list the connected Studio instances. Use only the instance whose name is `Outlaw City (placeId: 132163592957463)`.
  - Record that instance name next to each screenshot in TEST_EVIDENCE.md.
  - If the place ID can't be confirmed, the evidence doesn't go in the package.
- **Real output only.** Quote Output lines and test counts exactly as Studio printed them. Never paraphrase a number.
- **Solo vs multiplayer.** Mark anything that needs real players MULTIPLAYER UNVERIFIED (owner policy). Solo results never count as multiplayer proof.
- **No secrets.** No credentials, cookies, tokens or private addresses in any file.

## How to build a package

1. Create the folder and the diffs from the commit range, after the code snapshot (`src/`) has been exported and committed:
   ```
   python docs/audits/tools/make_audit_package.py <task-id> <base-commit> <head-commit> [screenshot ...]
   ```
   This copies the templates (it never overwrites filled-in files), writes `diffs/`, and copies the screenshots.
2. Fill in the five Markdown files (four reports + the auditor prompt).
3. Run `python docs/audits/tools/make_audit_package.py <task-id> --check <base> <head>`. It refuses while placeholders remain, then prints the prompt path and the exact .md files to upload: the four audit reports plus every `docs/*.md` changed in the range.
4. Commit the folder.

## Handoff message to the owner

The message must contain:
- the ready-to-paste auditor prompt (the contents of `00_AUDITOR_PROMPT.md`, posted as a copyable card);
- the exact list of .md files to upload (from `--check`);
- a short summary of the changes;
- the test outcomes;
- the unresolved risks;
- the questions for the auditor;

Then Claude waits for the owner's approval before the next significant implementation batch.
