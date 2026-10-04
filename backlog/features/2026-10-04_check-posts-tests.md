---
id: "2026-10-04_check-posts-tests"
title: "Add fixtures and tests for check_posts / pmlint posts"
status: "Completed"
priority: "High"
created: "2026-10-04"
last_updated: "2026-10-04"
category: "features"
related_cips: ["0009"]
owner: "Neil Lawrence"
dependencies:
- "2026-10-04_check-posts-validator"
tags:
- backlog
- pmlint
- tests
- posts
---

# Task: Add fixtures and tests for check_posts (CIP-0009)

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs.

## Description

Add fixture posts and a smoke/integration test (follow `tests/test_pmlint.sh` / `tests/test_check_volume.sh` style) covering:

- Valid post (pass)
- Broken YAML / missing frontmatter fences (fail)
- Missing required keys / bad `extras` shape (fail)
- `author` vs `bibtex_author` mismatch (fail)
- Non-printable / control character in a string field (fail)
- Assert `--check` does not modify the fixture tree

Wire into papersite CI if there is an existing pmlint test job.

## Acceptance Criteria

- [x] Fixtures exist under `tests/` for each failure class above plus one good post
- [x] Automated test fails on bad fixtures and passes on good
- [x] Posts `--check` leaves fixture tree unchanged
- [x] Papersite CI runs the new test (or documents how)

## Implementation Notes

Reuse directory layout conventions from existing volume fixtures. Keep fixtures minimal (one small `_posts` set).

## Related

- CIP: 0009
- Depends on: `2026-10-04_check-posts-validator`
- Related: `2026-10-04_pmlint-posts-mode`

## Progress Updates

### 2026-10-04

Task created as Ready when CIP-0009 was Accepted.

### 2026-10-04

Implemented as part of CIP-0009 v1.
