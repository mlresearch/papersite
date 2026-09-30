---
id: "2026-09-30_pmlint-check-fix"
title: "Wire pmlint --check and --fix to existing tidy + check_volume"
status: "Completed"
priority: "High"
created: "2026-09-30"
last_updated: "2026-09-30"
category: "features"
related_cips: ["0008"]
owner: "Neil Lawrence"
dependencies:
- "2026-09-30_tidy-bibtex-dry-run"
- "2026-09-30_pmlint-entrypoint"
tags:
- backlog
- pmlint
- check-volume
- tidy-bibtex
---

# Task: Wire pmlint --check and --fix (CIP-0008)

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs.

## Description

Compose existing tools behind `pmlint`:

**`--check` (default):** read-only sequence — `tidy_bibtex` dry-run with
`--strict --check-author-commas` → `bin/check_volume.sh` → optional
`tidy_bib_unicode --strict` (no write). Volume tree must be unchanged.

**`--fix`:** run `tidy_bibtex --fix-percent` (non-interactive safe
repairs only), then the same check path. Document what is / is not
auto-fixed. Unicode map edits and PDF moves are out of scope.

## Acceptance Criteria

- [x] `--check` exits `0`/`1` with a clear sectioned summary
- [x] `--check` leaves the volume directory bit-identical
- [x] `--fix` applies percent escaping via existing tidy, then re-checks
- [x] Optional unicode strict check documented; no interactive prompts in CI
- [x] No new validators invented — only compose existing CLIs
- [x] README documents check vs fix behaviour

## Implementation Notes

Depends on dry-run for tidy and the `pmlint` entrypoint. Do not implement
`check_volume --fix` PDF moves here (separate follow-on task).

## Related

- CIP: 0008
- Depends on: `2026-09-30_tidy-bibtex-dry-run`, `2026-09-30_pmlint-entrypoint`
- Next: `2026-09-30_pmlint-tests`, `2026-09-30_pmlint-pr-ci`

## Progress Updates

### 2026-09-30

Task created as Ready when CIP-0008 was Accepted.

Wired `--check` / `--fix` to compose tidy + `check_volume`. Marked
Completed as part of CIP-0008 v1.
