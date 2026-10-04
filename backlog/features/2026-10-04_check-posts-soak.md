---
id: "2026-10-04_check-posts-soak"
title: "Soak check_posts on real published volume _posts; triage false positives"
status: "Ready"
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

- [ ] Ran against at least three published volumes' `_posts` (record which)
- [ ] False positives classified; validator or docs adjusted as needed
- [ ] True positives either filed/fixed or explicitly deferred with reason
- [ ] Short note in CIP-0009 progress (or this task) on soak results
- [ ] Green light recorded before opening a fleet-rollout CIP

## Implementation Notes

Use local clones or sparse checkouts; do not require pushing workflows yet. Prefer volumes with known good recent posts plus one older volume.

## Related

- CIP: 0009
- Depends on: `2026-10-04_check-posts-tests`, `2026-10-04_pmlint-posts-mode`
- Unblocks: future fleet-rollout CIP

## Progress Updates

### 2026-10-04

Task created as Ready when CIP-0009 was Accepted.
