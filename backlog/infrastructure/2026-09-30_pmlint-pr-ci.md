---
id: "2026-09-30_pmlint-pr-ci"
title: "Add GitHub Actions workflow for pmlint --check on PRs"
status: "Ready"
priority: "Medium"
created: "2026-09-30"
last_updated: "2026-09-30"
category: "infrastructure"
related_cips: ["0008", "0004"]
owner: "Neil Lawrence"
dependencies:
- "2026-09-30_pmlint-check-fix"
tags:
- backlog
- pmlint
- github-actions
- ci-cd
---

# Task: Add GitHub Actions workflow for pmlint --check (CIP-0008)

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs.

## Description

Wire CIP-0004 Phase 1 / CIP-0008 PR gate: a reusable or example GitHub
Actions workflow that checks out the volume (or fixture), checks out
`mlresearch/papersite`, sets `PAPERSITE_ROOT`, and runs `pmlint --check`.
Fail the job on exit `1`. Document how a volume repo enables the
workflow.

PR comment bots are optional follow-on, not required for this task.

## Acceptance Criteria

- [ ] Workflow (or reusable workflow) lives under papersite `.github/`
- [ ] Runs `pmlint --check` with papersite checkout as `PAPERSITE_ROOT`
- [ ] Job fails when lint fails
- [ ] Docs explain enabling the workflow from a volume repository
- [ ] Optional: papersite CI smoke against an in-repo fixture volume

## Implementation Notes

Self-update in CI = checkout of papersite at `main` (or pinned SHA).
No deploy, no `create_volume` in this workflow.

## Related

- CIP: 0008, 0004
- Depends on: `2026-09-30_pmlint-check-fix`

## Progress Updates

### 2026-09-30

Task created as Ready when CIP-0008 was Accepted.
