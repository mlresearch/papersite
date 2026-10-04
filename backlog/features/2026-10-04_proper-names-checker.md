---
id: "2026-10-04_proper-names-checker"
title: "Add proper-name bracing check to check_volume / pmlint intake (CIP-000B Phase 2)"
status: "Ready"
priority: "High"
created: "2026-10-04"
last_updated: "2026-10-04"
category: "features"
related_cips: ["000B"]
owner: "Neil Lawrence"
dependencies:
- "2026-10-04_proper-names-yml"
tags:
- backlog
- bibtex
- titles
- proper-names
- check-volume
- pmlint
---

# Task: Proper-name bracing checker in intake lint (CIP-000B)

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs.

## Description

Load the curated proper-name YAML and check BibTeX `title` fields (v1 scope
per CIP-000B) for unprotected stems. Report key + context; exit non-zero on
failures. Prefer implementing in `lib/check_volume.rb` (helper OK) so
`bin/pmlint` intake composition picks it up automatically.

No auto-fix in v1. Posts-mode (`check_posts`) out of scope unless CIP is
amended.

## Acceptance Criteria

- [ ] Unprotected dictionary stems in `title` fail intake check (error)
- [ ] `{B}ayes` and `{Bayes}` (and equivalents) count as protected
- [ ] Whole-word matching only; documented negatives do not fire
- [ ] Runs via `check_volume` / `pmlint --check` without extra flags for v1
- [ ] Does not rewrite BibTeX

## Implementation Notes

Reuse `check_volume` reporting style (`error` / `ok` / section headers).
Keep dictionary load path stable relative to papersite root.

## Related

- CIP: 000B
- Depends on: `2026-10-04_proper-names-yml`
- Next: `2026-10-04_proper-names-tests-soak`

## Progress Updates

### 2026-10-04

Task created as Ready when CIP-000B was Accepted.
