---
id: "2026-10-04_fleet-campaign-pmlint-intake"
title: "Fleet campaign pmlint-intake-ci: config, pilot, bulk PRs"
status: "Proposed"
priority: "Medium"
created: "2026-10-04"
last_updated: "2026-10-04"
category: "infrastructure"
related_cips: ["000A", "0008", "0004"]
owner: "Neil Lawrence"
dependencies:
- "2026-10-04_pmfleet-apply-status"
- "2026-10-04_fleet-campaign-schema-docs"
tags:
- backlog
- fleet
- pmlint
- intake
- campaign
---

# Task: Campaign pmlint-intake-ci (CIP-000A / CIP-0008)

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs.

## Description

Roll out the intake `pmlint` PR workflow to unpublished volumes:

1. Add `fleet/campaigns/pmlint-intake-ci.yml`
2. Target branch policy: repo default (typically `main`)
3. Classify/skip published volumes (`gh-pages` present) appropriately
4. Pilot → bulk apply → status to close the gap

## Acceptance Criteria

- [ ] Campaign YAML committed and loadable by `pmfleet`
- [ ] Pilot on unpublished cohort; intake check runs on PRs
- [ ] Published volumes skipped (or otherwise not wrongly gated)
- [ ] Bulk apply completed or remaining gaps accounted for

## Implementation Notes

Lower priority than posts campaign if correction-PR gates are the acute
gap. Same tool invariants as posts campaign.

## Related

- CIP: 000A, 0008, 0004 (Phase 1 follow-on)
- Depends on: apply tool + schema docs
- Sibling: `2026-10-04_fleet-campaign-pmlint-posts`

## Progress Updates

### 2026-10-04

Task created as Proposed when CIP-000A was Accepted (blocked on pmfleet apply).
