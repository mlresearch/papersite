---
id: "2026-09-30_check-volume-fix"
title: "Implement check_volume --fix for stranded PDF/supp moves (follow-on)"
status: "Proposed"
priority: "Low"
created: "2026-09-30"
last_updated: "2026-09-30"
category: "features"
related_cips: ["0008"]
owner: "Neil Lawrence"
dependencies:
- "2026-09-30_pmlint-check-fix"
tags:
- backlog
- pmlint
- check-volume
- fix-mode
- follow-on
---

# Task: Implement check_volume --fix (CIP-0008 follow-on)

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs.

## Description

`check_volume.rb` documents `--fix` but does not implement it. After
`pmlint` v1 ships, implement safe auto-moves of stranded PDFs /
supplementary files into the volume root (and wire into `pmlint --fix`
if appropriate). Not required to close CIP-0008 v1.

## Acceptance Criteria

- [ ] `check_volume --fix` moves known stranded PDFs/supps to volume root
      when safe and unambiguous
- [ ] Refuses or reports clearly when moves would be ambiguous/destructive
- [ ] Tests cover fix and no-clobber cases
- [ ] `pmlint --fix` optionally invokes this after bib percent fixes
- [ ] Documented in README / check_volume header

## Implementation Notes

Keep Proposed until v1 lint path is stable. Prefer explicit, reviewable
moves over silent mass relocation.

## Related

- CIP: 0008

## Progress Updates

### 2026-09-30

Task created as Proposed (follow-on; not blocking CIP-0008 v1).
