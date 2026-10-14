"""Builds an auditor package for one task (see docs/audits/README.md).

Usage (from the repo root):
  python docs/audits/tools/make_audit_package.py <task-id> <base-commit> <head-commit> [screenshot ...]
  python docs/audits/tools/make_audit_package.py <task-id> --zip

The first form creates docs/audits/<task-id>/, copies the four templates (never overwriting a
file that already exists), writes diffs/ from `git diff base..head` for src/ and docs/, and
copies the given screenshots into screenshots/. The --zip form refuses to package while
any "{{...}}" placeholder is left in the four reports, then writes docs/audits/<task-id>.zip.
"""
import os
import re
import shutil
import subprocess
import sys
import zipfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
AUDITS = os.path.join(ROOT, "docs", "audits")
TEMPLATES = os.path.join(AUDITS, "templates")
REPORTS = ["AUDITOR_REPORT.md", "CHANGE_MANIFEST.md", "TEST_EVIDENCE.md", "AUDITOR_QUESTIONS.md"]
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
    changed = [line for line in git("diff", "--name-status", f"{base}..{head}", "--", "src", "docs").splitlines() if line]
    with open(os.path.join(folder, "diffs", "ALL.diff"), "w", encoding="utf-8", newline="\n") as f:
        f.write(git("diff", f"{base}..{head}", "--", "src", "docs"))
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


def package(task_id):
    folder = os.path.join(AUDITS, task_id)
    problems = []
    for name in REPORTS:
        with open(os.path.join(folder, name), encoding="utf-8") as f:
            for number, line in enumerate(f, 1):
                if PLACEHOLDER.search(line):
                    problems.append(f"{name}:{number}: {line.strip()}")
    if problems:
        print("Unfilled placeholders, not packaging:")
        print("\n".join(problems))
        sys.exit(1)
    target = os.path.join(AUDITS, task_id + ".zip")
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as z:
        for directory, _, files in os.walk(folder):
            for file in sorted(files):
                full = os.path.join(directory, file)
                z.write(full, os.path.join(task_id, os.path.relpath(full, folder)))
    print("wrote", os.path.relpath(target, ROOT), os.path.getsize(target), "bytes")


def main(argv):
    if len(argv) < 2 or not TASK_ID.match(argv[1]):
        print(__doc__)
        sys.exit(2)
    if len(argv) == 3 and argv[2] == "--zip":
        package(argv[1])
    elif len(argv) >= 4:
        build(argv[1], argv[2], argv[3], argv[4:])
    else:
        print(__doc__)
        sys.exit(2)


if __name__ == "__main__":
    main(sys.argv)
