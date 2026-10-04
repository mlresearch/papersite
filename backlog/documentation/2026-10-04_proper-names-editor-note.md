---
id: "2026-10-04_proper-names-editor-note"
title: "Document title proper-name bracing for editors (CIP-000B)"
status: "Proposed"
priority: "Low"
created: "2026-10-04"
last_updated: "2026-10-04"
category: "documentation"
related_cips: ["000B"]
owner: "Neil Lawrence"
dependencies:
- "2026-10-04_proper-names-tests-soak"
tags:
- backlog
- documentation
- bibtex
- titles
- proper-names
---

# Task: Document title proper-name bracing (CIP-000B)

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs.

## Description

After the checker is stable, add a short editor-facing note (PMLR FAQ and/or
papersite README) on bracing proper names in titles (`{B}ayes`, `{M}arkov`)
and point at the curated dictionary. Suitable for CIP Closed → compression.

## Acceptance Criteria

- [ ] FAQ or README states the bracing convention with examples
- [ ] Mentions that intake lint may reject unprotected dictionary stems
- [ ] Links or path to `proper_names.yml` for contributors extending the list

## Implementation Notes

Defer until Phase 2 soak is done so the documented policy matches behaviour.

## Related

- CIP: 000B
- Depends on: `2026-10-04_proper-names-tests-soak`

## Progress Updates

### 2026-10-04

Task created (Proposed) when CIP-000B was Accepted; implement near Closed.
