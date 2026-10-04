---
id: "2026-10-04_fleet-next-campaign-checklist"
title: "Document checklist for adding the next fleet campaign"
status: "Completed"
priority: "Low"
created: "2026-10-04"
last_updated: "2026-10-04"
category: "documentation"
related_cips: ["000A"]
owner: "Neil Lawrence"
dependencies:
- "2026-10-04_fleet-campaign-schema-docs"
tags:
- backlog
- fleet
- documentation
---

# Task: Next-campaign checklist (CIP-000A)

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs.

## Description

Write a short checklist (in `fleet/README.md` or root docs) for adding a
future campaign: YAML fields, classifier tests, pilot sizes, apply flags,
new-volume template update, and “no fleet needed” rationale option for
CIPs that introduce volume-local files.

## Acceptance Criteria

- [x] Checklist covers inventory → plan → pilot → apply → status → birth path
- [x] Reminds authors to link `related_cips: ["000A"]` on campaign backlog
- [x] States CIP-0007 boundary (not a deploy engine)

## Implementation Notes

Can stay thin; prefer linking schema docs over duplicating the full YAML
reference.

## Related

- CIP: 000A
- Depends on: `2026-10-04_fleet-campaign-schema-docs`

## Progress Updates

### 2026-10-04

Task created as Ready when CIP-000A was Accepted.

### 2026-10-04

Checklist added to `fleet/README.md`.
