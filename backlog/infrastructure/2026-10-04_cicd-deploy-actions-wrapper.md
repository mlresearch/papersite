---
id: "2026-10-04_cicd-deploy-actions-wrapper"
title: "Thin Actions/docs wrapper around deploy_volume.sh (CIP-0004 Phase 3)"
status: "Proposed"
priority: "Medium"
created: "2026-10-04"
last_updated: "2026-10-04"
category: "infrastructure"
related_cips: ["0004", "0007"]
owner: "Neil Lawrence"
dependencies:
- "2026-10-04_deploy-batched-path"
tags:
- backlog
- ci-cd
- deploy
- github-actions
---

# Task: Deploy automation wrapper (CIP-0004 Phase 3)

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs.

## Description

After CIP-0007’s batched `deploy_volume.sh` exists, add a thin guarded way to
invoke it for production publish — either a GitHub Actions workflow with
environment approval or a documented one-command path that CI can mirror.

Must **call** `deploy_volume.sh` (including `--dry-run` / batched flags), not
re-port branch surgery into YAML. If a volume-local workflow file is required,
fleet install is a later CIP-000A campaign — out of scope here.

## Acceptance Criteria

- [ ] Wrapper invokes `deploy_volume.sh`; no second deploy implementation
- [ ] Dry-run / approval gate before any production push
- [ ] Documents secrets, permissions, and failure/resume expectations
- [ ] Branch invariants match CIP-0007 after a successful run
- [ ] Explicit note on 000A boundary if a volume-local workflow artifact appears

## Implementation Notes

Blocked on `2026-10-04_deploy-batched-path`. Prefer manual
`workflow_dispatch` + environment protection over push-to-main auto-deploy
for v1. Status stays Proposed until 0007 path is usable.

## Related

- CIP: 0004, 0007
- Depends on: `2026-10-04_deploy-batched-path`
- Boundary: CIP-000A (fleet artifact install only)

## Progress Updates

### 2026-10-04

Task created as Proposed (blocked on CIP-0007 batched path) when CIP-0004
was Accepted.
