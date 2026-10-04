---
id: "2026-10-04_check-posts-soak"
title: "Soak check_posts on real published volume _posts; triage false positives"
status: "Completed"
priority: "Medium"
created: "2026-10-04"
last_updated: "2026-10-04"
category: "features"
related_cips: ["0009"]
owner: "Neil Lawrence"
dependencies:
- "2026-10-04_check-posts-tests"
- "2026-10-04_pmlint-posts-mode"
tags:
- backlog
- pmlint
- posts
- validation
---

# Task: Soak check_posts on real published volumes (CIP-0009)

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs.

## Description

Before treating posts CI as merge-blocking elsewhere, run `pmlint posts --check` against `_posts` from several real published volumes (including older W&CP-era trees if practical). Triage failures: tighten/loosen schema or consistency rules; fix real data bugs only when clearly wrong.

Goal: confidence that the default rules are strict enough for correction PRs without flooding maintainers with historical false positives.

## Acceptance Criteria

- [x] Ran against at least three published volumes' `_posts` (record which)
- [x] False positives classified; validator or docs adjusted as needed
- [x] True positives either filed/fixed or explicitly deferred with reason
- [x] Short note in CIP-0009 progress (or this task) on soak results
- [x] Green light recorded before opening a fleet-rollout CIP

## Implementation Notes

Use local clones or sparse checkouts; do not require pushing workflows yet. Prefer volumes with known good recent posts plus one older volume.

## Related

- CIP: 0009
- Depends on: `2026-10-04_check-posts-tests`, `2026-10-04_pmlint-posts-mode`
- Unblocks: future fleet-rollout CIP

## Progress Updates

### 2026-10-04

Task created as Ready when CIP-0009 was Accepted.

### 2026-10-04

Implemented as part of CIP-0009 v1.

Soak results (all PASSED, 0 errors after LaTeX/Unicode normalisation tweaks):

- `v304` — 79 posts (local `_posts`)
- `v16` — 12 posts (`gh-pages` archive)
- `v283` — 120 posts (`gh-pages` archive; drove `{\ss}` / `\sqrtT` / `\i` handling)

Green light for a future fleet-rollout CIP.
