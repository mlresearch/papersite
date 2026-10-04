---
id: "2026-10-04_fleet-campaign-pmlint-posts"
title: "Fleet campaign pmlint-posts-ci: config, pilot, bulk PRs"
status: "Ready"
priority: "High"
created: "2026-10-04"
last_updated: "2026-10-04"
category: "infrastructure"
related_cips: ["000A", "0009"]
owner: "Neil Lawrence"
dependencies:
- "2026-10-04_pmfleet-apply-status"
- "2026-10-04_fleet-campaign-schema-docs"
# both dependencies Completed
tags:
- backlog
- fleet
- pmlint
- posts
- campaign
---

# Task: Campaign pmlint-posts-ci (CIP-000A / CIP-0009)

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs.

## Description

Roll out the posts lint workflow to published volumes:

1. Add `fleet/campaigns/pmlint-posts-ci.yml` (source =
   papersite posts workflow example → volume `.github/workflows/…`)
2. Target branch policy: `gh-pages-if-posts` (or documented equivalent)
3. Pilot on a small published cohort; fix classifiers / branch detection
4. Bulk `apply --open-prs`; track `status` until `missing` is empty or
   accounted as skip/custom

Finishes the fleet half of REQ-0005 / CIP-0009 soak follow-on.

## Acceptance Criteria

- [ ] Campaign YAML committed and loadable by `pmfleet`
- [ ] Pilot PRs opened and validated (workflow runs on `_posts` changes)
- [ ] Bulk apply completed or remaining gaps explicitly skip/custom
- [ ] No force-push; custom repos left alone unless strategy documented

## Implementation Notes

Status Proposed until apply tool exists. Coordinate with any still-open
`fix/posts-yaml-lint` volume data PRs — CI install is separate from data
fixes.

## Related

- CIP: 000A, 0009
- REQ: 0005
- Depends on: apply tool + schema docs
- Sibling: `2026-10-04_fleet-campaign-pmlint-intake`

## Progress Updates

### 2026-10-04

Task created as Proposed when CIP-000A was Accepted (blocked on pmfleet apply).

### 2026-10-04

Campaign YAML landed with inventory/plan work
(`fleet/campaigns/pmlint-posts-ci.yml`). Pilot/bulk still blocked on apply.

### 2026-10-04

Unblocked: `pmfleet apply`/`status` Complete. Status → Ready for pilot.
