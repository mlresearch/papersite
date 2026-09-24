---
id: "2026-09-24_check-volume-non-printable"
title: "Add non-printable character check to check_volume.rb (CIP-0006)"
status: "Completed"
priority: "High"
created: "2026-09-24"
last_updated: "2026-09-24"
category: "features"
related_cips: ["0006"]
owner: "Neil Lawrence"
dependencies: []
tags:
- backlog
- check-volume
- data-integrity
- bibtex
---

# Task: Add non-printable character check to check_volume.rb (CIP-0006)

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs.

## Description

Implement CIP-0006: add `check_non_printable_characters` to
`lib/check_volume.rb` so submitted BibTeX containing C0/C1 control
characters (excluding tab/newline/CR) is rejected at volume intake,
before conversion or publication.

## Acceptance Criteria

- [x] New check in `lib/check_volume.rb`, UTF-8 code-point aware (no
      false positives on legitimate multi-byte UTF-8 punctuation)
- [x] Fixtures reproducing the v283 mojibake and v316 STX patterns
- [x] `tests/test_check_volume.sh` assertions pass, including
      `assert_no_error` on `clean_volume` (with UTF-8 punctuation present)
- [x] Header comment in `check_volume.rb` and `tests/README.md` updated

## Implementation Notes

See CIP-0006 for the UTF-8 vs raw-byte subtlety and the fixture
extraction approach. Implemented by iterating decoded Unicode code
points (excluding tab/LF/CR), so em dashes and curly quotes in
`clean_volume` are allowed while `U+0080`/`U+009D`/`U+0002` fail.

## Related

- CIP: 0006
- Bugs that motivated this: `2026-09-24_v283-citeproc-yaml-invalid-utf8`,
  `2026-09-24_v316-citeproc-yaml-control-character`

## Progress Updates

### 2026-09-24

Task created as In Progress when CIP-0006 was Accepted.

Implemented `check_non_printable_characters`, added
`tests/fixtures/v283_original/` and `tests/fixtures/v316_original/`,
extended `clean_volume` with legitimate UTF-8 punctuation, and updated
`tests/test_check_volume.sh`. Suite: 45 passed, 0 failed. Marking
Completed; CIP-0006 moved to Implemented pending user validation.
