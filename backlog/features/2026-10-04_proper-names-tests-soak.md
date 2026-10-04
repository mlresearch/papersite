---
id: "2026-10-04_proper-names-tests-soak"
title: "Fixtures and soak for proper-name bracing checker (CIP-000B Phase 2)"
status: "In Progress"
priority: "Medium"
created: "2026-10-04"
last_updated: "2026-10-04"
category: "features"
related_cips: ["000B"]
owner: "Neil Lawrence"
dependencies:
- "2026-10-04_proper-names-checker"
tags:
- backlog
- bibtex
- titles
- proper-names
- tests
- soak
---

# Task: Fixtures and soak for proper-name checker (CIP-000B)

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs.

## Description

Add fixture coverage for the proper-name bracing check and soak it on a
sample of local volume BibTeX. Triage false positives into YAML aliases or
match-rule tweaks; freeze v1 severity/policy afterward.

## Acceptance Criteria

- [x] Fixtures: protected OK; unprotected stem fails; word-boundary negative;
      braced forms pass
- [x] Automated test wired like other `check_volume` / `pmlint` smoke tests
- [ ] Soak notes (in CIP or this task) for at least a representative local
      sample; YAML updated if needed
- [ ] CIP-000B policy table confirmed or amended from soak findings

## Implementation Notes

Keep soak reproducible (document clone dir / command). Do not auto-edit
volume repos during soak — report only.

## Related

- CIP: 000B
- Depends on: `2026-10-04_proper-names-checker`
- Follow-up (post-Closed): editor-facing FAQ/README note (CIP compression)

## Progress Updates

### 2026-10-04

Task created as Ready when CIP-000B was Accepted.

### 2026-10-04

Fixtures `proper_names_unprotected` / `proper_names_ok` + tests in
`tests/test_check_volume.sh`. Sample soak on `lawrennd/r13` surfaces many
unprotected dictionary stems plus unknown acronyms (ABC, AIXI, …).
