---
id: "2026-09-30_tidy-bibtex-dry-run"
title: "Add dry-run mode to tidy_bibtex so pmlint --check never writes"
status: "Completed"
priority: "High"
created: "2026-09-30"
last_updated: "2026-09-30"
category: "features"
related_cips: ["0008"]
owner: "Neil Lawrence"
dependencies: []
tags:
- backlog
- pmlint
- tidy-bibtex
- check-mode
---

# Task: Add dry-run mode to tidy_bibtex (CIP-0008)

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs.

## Description

Today `lib/tidy_bibtex.rb` always writes an output file, even when only
reporting issues under `--strict`. CIP-0008 requires `pmlint --check` to
leave the volume tree bit-identical. Add a `--dry-run` (or equivalent)
path that runs the same checks (including `--strict` and
`--check-author-commas`) and exits non-zero on issues without writing
any file.

## Acceptance Criteria

- [x] `tidy_bibtex.rb` supports `--dry-run` (name may vary; behaviour fixed)
- [x] With `--dry-run`, no output BibTeX is created or overwritten
- [x] `--strict --dry-run` exits `1` when issues exist, `0` when clean
- [x] `--check-author-commas` still reports under dry-run
- [x] Existing non-dry-run behaviour unchanged (still writes output)
- [x] Unit/CLI tests cover dry-run no-write and exit codes

## Implementation Notes

Preferred over writing to `/tmp` and deleting. See CIP-0008 `--check`
invariant. Keep the change surgical — do not redesign the cleaner.

## Related

- CIP: 0008
- Depends on this: `2026-09-30_pmlint-check-fix`

## Progress Updates

### 2026-09-30

Task created as Ready when CIP-0008 was Accepted.

Implemented `--dry-run` on `tidy_bibtex.rb` so strict/author-comma checks
report without writing. Marked Completed as part of CIP-0008 v1.
