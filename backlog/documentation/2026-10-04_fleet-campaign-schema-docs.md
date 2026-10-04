---
id: "2026-10-04_fleet-campaign-schema-docs"
title: "Document fleet campaign YAML schema and fleet/ layout"
status: "Completed"
priority: "Medium"
created: "2026-10-04"
last_updated: "2026-10-04"
category: "documentation"
related_cips: ["000A"]
owner: "Neil Lawrence"
dependencies: []
tags:
- backlog
- fleet
- documentation
---

# Task: Fleet campaign schema and docs (CIP-000A)

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs.

## Description

Land the papersite `fleet/` (or equivalent) layout and document the
campaign config schema from CIP-000A: source paths, dest paths, target
branch policy, classifiers, pilot sizes, PR branch/title, related CIP/REQ
links.

Include a short `fleet/README.md` explaining inventory → plan → pilot →
apply → status, and the 0007 boundary (fleet does not deploy volumes).

## Acceptance Criteria

- [x] Schema fields documented with the CIP sketch as the baseline
- [x] `fleet/campaigns/` (or chosen path) exists with a placeholder or
      example pointing at first campaigns
- [x] Target branch policies (`default`, `gh-pages-if-posts`, `explicit`)
      explained
- [x] Invariants (PR-only, no force-push, custom not overwritten) stated

## Implementation Notes

Can land before or alongside `pmfleet` inventory; keep schema stable enough
for the posts/intake campaign YAMLs.

## Related

- CIP: 000A
- Parallel: `2026-10-04_pmfleet-inventory-plan`

## Progress Updates

### 2026-10-04

Task created as Ready when CIP-000A was Accepted.

### 2026-10-04

Landed `fleet/README.md` plus `pmlint-posts-ci.yml` /
`pmlint-intake-ci.yml` campaign configs.
