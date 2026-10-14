"""Builds an auditor package for one task (see docs/audits/README.md).

Usage (from the repo root):
  python docs/audits/tools/make_audit_package.py <task-id> <base-commit> <head-commit> [screenshot ...]
  python docs/audits/tools/make_audit_package.py <task-id> --check <base-commit> <head-commit>

The first form creates docs/audits/<task-id>/, copies the five templates (never overwriting a
file that already exists), writes diffs/ from `git diff base..head` for src/ and docs/, and
copies the given screenshots into screenshots/. The --check form refuses while any "{{...}}"
placeholder is left in the five files, then prints the Markdown files the owner uploads to the
auditor: the four audit reports plus every docs/*.md changed in base..head (owner rule
2026-10-14: the auditor takes the edited .md files and a pasted prompt, no ZIP).
"""
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
AUDITS = os.path.join(ROOT, "docs", "audits")
TEMPLATES = os.path.join(AUDITS, "templates")
REPORTS = ["AUDITOR_REPORT.md", "CHANGE_MANIFEST.md", "TEST_EVIDENCE.md", "AUDITOR_QUESTIONS.md", "00_AUDITOR_PROMPT.md"]
TASK_ID = re.compile(r"^\d{4}-\d{2}-\d{2}_[A-Za-z0-9._-]+$")
PLACEHOLDER = re.compile(r"\{\{[^}]*\}\}")


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, check=True, capture_output=True, text=True, encoding="utf-8").stdout


def build(task_id, base, head, screenshots):
    folder = os.path.join(AUDITS, task_id)
    os.makedirs(os.path.join(folder, "diffs"), exist_ok=True)
    os.makedirs(os.path.join(folder, "screenshots"), exist_ok=True)
    for name in REPORTS:
        target = os.path.join(folder, name)
        if not os.path.exists(target):
            shutil.copyfile(os.path.join(TEMPLATES, name), target)
            print("template ", os.path.relpath(target, ROOT))
    changed = [line for line in git("diff", "--name-status", f"{base}..{head}", "--", "src", "docs", ":(exclude)docs/audits").splitlines() if line]
    with open(os.path.join(folder, "diffs", "ALL.diff"), "w", encoding="utf-8", newline="\n") as f:
        f.write(git("diff", f"{base}..{head}", "--", "src", "docs", ":(exclude)docs/audits"))
    for line in changed:
        status, path = line.split("\t")[0], line.split("\t")[-1]
        if not path.startswith("src/"):
            continue
        name = path[len("src/"):].replace("/", "__") + ".diff"
        with open(os.path.join(folder, "diffs", name), "w", encoding="utf-8", newline="\n") as f:
            f.write(git("diff", f"{base}..{head}", "--", path))
    with open(os.path.join(folder, "diffs", "FILES.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write(f"git diff --name-status {base}..{head} -- src docs\n\n" + "\n".join(changed) + "\n")
    for shot in screenshots:
        shutil.copy2(shot, os.path.join(folder, "screenshots", os.path.basename(shot)))
    print(f"{len(changed)} changed paths; diffs written to {os.path.relpath(os.path.join(folder, 'diffs'), ROOT)}")


def check(task_id, base, head):
    folder = os.path.join(AUDITS, task_id)
    problems = []
    for name in REPORTS:
        with open(os.path.join(folder, name), encoding="utf-8") as f:
            for number, line in enumerate(f, 1):
                if PLACEHOLDER.search(line):
                    problems.append(f"{name}:{number}: {line.strip()}")
    if problems:
        print("Unfilled placeholders:")
        print("\n".join(problems))
        sys.exit(1)
    uploads = [os.path.join(folder, name) for name in REPORTS if name != "00_AUDITOR_PROMPT.md"]
    for extra in sorted(os.listdir(folder)):  # e.g. SOURCE_DIFFS.md
        if extra.endswith(".md") and extra not in REPORTS:
            uploads.append(os.path.join(folder, extra))
    for line in git("diff", "--name-only", f"{base}..{head}", "--", "docs").splitlines():
        if line.endswith(".md") and not line.startswith("docs/audits/"):
            uploads.append(os.path.join(ROOT, line))
    print("Prompt to paste: " + os.path.join(folder, "00_AUDITOR_PROMPT.md"))
    print("Files to upload:")
    for path in uploads:
        print("  " + os.path.normpath(path))


def main(argv):
    if len(argv) < 2 or not TASK_ID.match(argv[1]):
        print(__doc__)
        sys.exit(2)
    if len(argv) == 5 and argv[2] == "--check":
        check(argv[1], argv[3], argv[4])
    elif len(argv) >= 4:
        build(argv[1], argv[2], argv[3], argv[4:])
    else:
        print(__doc__)
        sys.exit(2)


if __name__ == "__main__":
    main(sys.argv)
