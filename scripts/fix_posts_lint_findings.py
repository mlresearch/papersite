#!/usr/bin/env python3
"""Apply mechanical volume-side fixes for pmlint posts findings.

Only edits clear data faults (not legitimate title wording differences).
Run from anywhere; expects ~/mlresearch/vNNN|rNNN checkouts.
"""
from __future__ import annotations

import re
import subprocess
import tempfile
import shutil
from pathlib import Path

ROOT = Path("/Users/neil/mlresearch")

# Hand-verified author/metadata corrections (volume at fault)
AUTHOR_FIXES = {
    # volume, filename -> list of (match_family_or_given, new_family) or special ops
    ("v196", "2023-01-23-migus22a.md"): [("Gallinari1", "Gallinari")],
    ("v138", "2020-02-02-tehrani20a.md"): [("= 485-496", "Masouleh")],
    ("v201", "2023-02-13-raj23a.md"): [("Şim\\scekli", "Şimşekli"), ("Şim\\\\scekli", "Şimşekli")],
    ("v244", "2024-09-12-poonia24a.md"): [("Ze\\vcević", "Zečević"), ("Ze\\\\vcević", "Zečević")],
    ("v216", "2023-07-02-ma23a.md"): None,  # bibtex Lui -> Liu handled in BIBTEX_FIXES
}

BIBTEX_FIXES = {
    ("v216", "2023-07-02-ma23a.md"): ("Lui, Yanwei", "Liu, Yanwei"),
    ("v37", "2015-06-01-changb15.md"): (
        "Chang, Kai-Wei and Krishnamurthy, Akshay and Daum\\'e, III, Hal and Langford, John",
        "Chang, Kai-Wei and Krishnamurthy, Akshay and Agarwal, Alekh and Daum\\'e, III, Hal and Langford, John",
    ),
}

# Non-printable replacements when the intended char is obvious
NONPRINT_FIXES = {
    # (volume, file) -> list of (bad_char, replacement)
}


def volume_posts_dir(vol: str) -> Path | None:
    d = ROOT / vol
    if (d / "_posts").is_dir() and any((d / "_posts").glob("*.md")):
        return d / "_posts"
    return None


def fix_software_line(line: str) -> str:
    m = re.match(r"^(software:\s*)(.*)$", line)
    if not m:
        return line
    prefix, raw = m.group(1), m.group(2).strip()
    # strip quotes
    q = ""
    if (raw.startswith('"') and raw.endswith('"')) or (raw.startswith("'") and raw.endswith("'")):
        q = raw[0]
        raw = raw[1:-1]
    if raw.strip().lower() == "nan" or raw.strip() == "":
        return ""  # drop line
    raw = re.sub(r"\s+", "", raw)
    if not re.match(r"https?://", raw, re.I):
        if raw.startswith("github.com/") or raw.startswith("gitlab.com/") or raw.startswith("bitbucket.org/"):
            raw = "https://" + raw
        elif "/" in raw and not raw.startswith("http"):
            # google-research/... style
            raw = "https://github.com/" + raw.lstrip("/")
    if q:
        return f"{prefix}{q}{raw}{q}\n"
    # prefer quoting
    return f'{prefix}"{raw}"\n'


def fix_pdf_or_link_spaces(line: str) -> str:
    """Remove spaces inside http(s) URLs on pdf:/link: lines (volume typos)."""
    def repl(m):
        return m.group(0).replace(" ", "")
    return re.sub(r"https?://[^\s\"']+", repl, line)


def strip_controls(text: str) -> str:
    out = []
    for ch in text:
        o = ord(ch)
        if o in (0x09, 0x0A, 0x0D):
            out.append(ch)
        elif o <= 0x1F or 0x7F <= o <= 0x9F:
            # drop C0/C1 junk; common mojibake around quotes -> skip
            continue
        else:
            out.append(ch)
    return "".join(out)


def fix_file(path: Path, vol: str) -> list[str]:
    notes = []
    original = path.read_text(encoding="utf-8", errors="surrogateescape")
    text = strip_controls(original)
    if text != original:
        notes.append("stripped non-printables")

    lines = text.splitlines(keepends=True)
    new_lines = []
    for line in lines:
        if line.startswith("software:"):
            fixed = fix_software_line(line)
            if fixed == "":
                notes.append("dropped software: nan/empty")
                continue
            if fixed != line:
                notes.append("fixed software URL")
            new_lines.append(fixed if fixed.endswith("\n") else fixed + "\n")
            continue
        if line.startswith("pdf:") or "link:" in line[:20]:
            fixed = fix_pdf_or_link_spaces(line)
            if fixed != line:
                notes.append("removed spaces in URL")
            new_lines.append(fixed)
            continue
        new_lines.append(line)

    text = "".join(new_lines)

    key = (vol, path.name)
    if key in BIBTEX_FIXES:
        old, new = BIBTEX_FIXES[key]
        if old in text:
            text = text.replace(old, new, 1)
            notes.append("fixed bibtex_author")
    if key in AUTHOR_FIXES and AUTHOR_FIXES[key]:
        for a, b in AUTHOR_FIXES[key]:
            # family: line
            pat = f"family: {a}"
            if pat in text:
                text = text.replace(pat, f"family: {b}")
                notes.append(f"family {a!r}->{b!r}")
            elif a in text:
                text = text.replace(a, b)
                notes.append(f"replaced {a!r}->{b!r}")

    # Specific family latex leftovers in YAML
    text2 = text
    text2 = text2.replace("family: Şim\\scekli", "family: Şimşekli")
    text2 = text2.replace("family: Ze\\vcević", "family: Zečević")
    if text2 != text:
        notes.append("fixed latex-in-family")
        text = text2

    if text != original and notes:
        path.write_text(text, encoding="utf-8")
    return notes


def main():
    # Volumes that still fail for data reasons (from latest catalog) + software volumes
    vols = [
        "v18","v37","v38","v48","v52","v56","v62","v65","v73","v78","v83","v97",
        "v108","v116","v118","v119","v120","v123","v125","v133","v134","v138","v139",
        "v151","v162","v166","v180","v191","v196","v198","v201","v206","v216","v217",
        "v235","v244","v258","v267","v284","v286","v291","v293","v300","v305","v306",
        "v307","v321","v337",
    ]
    changed = []
    for vol in vols:
        posts = volume_posts_dir(vol)
        if posts is None:
            # try gh-pages checkout worktree would be needed; skip if not local
            print(f"SKIP {vol} (no local _posts workdir)")
            continue
        for path in sorted(posts.glob("*.md")):
            notes = fix_file(path, vol)
            if notes:
                changed.append((vol, path.name, notes))
                print(f"FIX  {vol}/{path.name}: {', '.join(notes)}")
    print(f"\nUpdated {len(changed)} files")


if __name__ == "__main__":
    main()
