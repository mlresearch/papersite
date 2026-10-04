---
id: "2026-10-04_cicd-compile-phase-design"
title: "Specify CIP-0004 Phase 2 auto-compilation design"
status: "Ready"
priority: "Medium"
created: "2026-10-04"
last_updated: "2026-10-04"
category: "features"
related_cips: ["0004"]
owner: "Neil Lawrence"
dependencies: []
tags:
- backlog
- ci-cd
- compile
- design
---

# Task: Specify auto-compilation design (CIP-0004 Phase 2)

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs.

## Description

Resolve the open Phase 2 design questions in [CIP-0004](../../cip/cip0004.md)
and either expand that section into an implementable plan or split a short
compile CIP. Decisions required:

- Trigger: merge to `main`, `workflow_dispatch` only, or both
- Output: Actions artifact vs staging branch vs PR back to the volume
- Published date: auto-inject vs workflow input
- Permissions / which repos may run compile
- How this relates to local `create_volume.rb` (parity target)

No production compile workflow implementation in this task — design only
(plus optional stub/workflow sketch if it clarifies the plan).

## Acceptance Criteria

- [ ] Trigger, output, date, and permissions choices written into CIP-0004
      (or a new child CIP) with rationale
- [ ] Parity target vs local `create_volume.rb` stated
- [ ] Follow-on implementation backlog task(s) listed or explicitly deferred
- [ ] No silent scope creep into deploy (Phase 3) or fleet (CIP-000A)

## Implementation Notes

If the design grows past a short CIP-0004 section, create a child CIP and
point Phase 2 ownership there. Prefer artifact + manual review over
unattended production publish.

## Related

- CIP: 0004
- Sibling: `2026-10-04_cicd-deploy-actions-wrapper` (Phase 3; blocked on 0007)

## Progress Updates

### 2026-10-04

Task created as Ready when CIP-0004 was Accepted.
