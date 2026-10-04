---
id: "2026-10-04_deploy-batched-flags-dry-run"
title: "Add deploy_volume.sh batched flags and dry-run letter counts"
status: "Ready"
priority: "High"
created: "2026-10-04"
last_updated: "2026-10-04"
category: "features"
related_cips: ["0007"]
owner: "Neil Lawrence"
dependencies: []
tags:
- backlog
- deploy
- batched
- dry-run
---

# Task: Batched deploy flags and dry-run (CIP-0007)

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs.

## Description

Extend `bin/deploy_volume.sh` with flag parsing and a non-mutating plan:

- `--batched` — force letter-batched mode
- `--batch-threshold N` — auto-batch when `max(assets, posts) > N` (default 500)
- `--dry-run` — print letter → asset/post counts, chosen mode, and planned steps; no git writes/pushes
- `--from-letter X` — parse and report resume start (full resume behaviour in path task)
- Keep existing `SKIP_CONFIRM=1`

Refactor enough helpers (`count_by_letter`, mode selection) that the batched path task can call them.

## Acceptance Criteria

- [ ] New flags parse without breaking the legacy no-flag invocation
- [ ] `--dry-run` exits 0 with per-letter counts and mode; no commits/pushes
- [ ] Threshold and `--batched` select mode as specified in CIP-0007
- [ ] `--from-letter` is accepted (resume execution may land in path task)

## Implementation Notes

Letter key = first character of paper filestub / PDF stem, lowercase `a`–`z`.
Document non-`a–z` stems if encountered (skip or bucket — decide in path task).

## Related

- CIP: 0007
- Next: `2026-10-04_deploy-batched-path`

## Progress Updates

### 2026-10-04

Task created as Ready when CIP-0007 was Accepted.
