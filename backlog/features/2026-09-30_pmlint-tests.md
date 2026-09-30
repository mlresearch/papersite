---
id: "2026-09-30_pmlint-tests"
title: "Add pmlint smoke and no-touch tests"
status: "Completed"
priority: "High"
created: "2026-09-30"
last_updated: "2026-09-30"
category: "features"
related_cips: ["0008"]
owner: "Neil Lawrence"
dependencies:
- "2026-09-30_pmlint-check-fix"
tags:
- backlog
- pmlint
- testing
---

# Task: Add pmlint smoke and no-touch tests (CIP-0008)

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs.

## Description

Add tests for `pmlint`: argument parsing / skip-update path, failure
aggregation, pass on known-good fixtures, fail on known-bad fixtures,
and a hard assertion that `--check` does not modify any file under the
fixture volume. Reuse `tests/test_check_volume.sh` fixtures where
possible.

## Acceptance Criteria

- [x] Smoke tests for `--check` pass/fail on fixtures
- [x] Assertion that `--check` leaves fixture tree unchanged (checksums or
      recursive compare before/after)
- [x] `PMLINT_SKIP_UPDATE=1` path covered so CI does not need network git
      update
- [x] Tests documented in `tests/README.md` (or equivalent)
- [x] Suite passes locally with existing check_volume tests still green

## Implementation Notes

Prefer extending the bash test style used for `check_volume` unless a
Ruby unit test fits better for dry-run alone (that may live with
tidy_bibtex tests).

## Related

- CIP: 0008
- Depends on: `2026-09-30_pmlint-check-fix`

## Progress Updates

### 2026-09-30

Task created as Ready when CIP-0008 was Accepted.

Added `tests/test_pmlint.sh` (smoke, no-touch, skip-update). Marked
Completed as part of CIP-0008 v1.
