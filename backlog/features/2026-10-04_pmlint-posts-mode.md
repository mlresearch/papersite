---
id: "2026-10-04_pmlint-posts-mode"
title: "Wire pmlint posts --check mode (keep intake skip on published)"
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
- posts
- cli
---

# Task: Wire pmlint posts --check mode (CIP-0009)

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs.

## Description

Extend `bin/pmlint` with a **posts** path that runs the check_posts validator, without changing intake behaviour:

- Unpublished volumes: existing intake `pmlint --check` unchanged (skip when published)
- Published / correction path: `pmlint posts --check` runs post validation
- Optional: `--changed` to limit to PR-touched `_posts` files when CI provides the list

Document CLI in root `README.md`. Self-update / `PAPERSITE_ROOT` resolution stays as in CIP-0008.

## Acceptance Criteria

- [x] `pmlint posts --check` invokes check_posts and exits `0`/`1`
- [x] Intake `pmlint --check` still skips published volumes unless `--force`
- [x] `--check` posts mode is non-mutating
- [x] Optional `--changed` documented (implement if straightforward for CI)
- [x] README documents posts vs intake modes

## Implementation Notes

Prefer explicit `posts` subcommand/flag over silently changing default `--check` on published volumes, unless auto-dispatch is clearly safer for editors. Do not invent a second top-level binary.

## Related

- CIP: 0009
- Depends on: `2026-10-04_check-posts-validator`
- Next: `2026-10-04_pmlint-posts-pr-ci`

## Progress Updates

### 2026-10-04

Task created as Ready when CIP-0009 was Accepted.

### 2026-10-04

Implemented as part of CIP-0009 v1.
