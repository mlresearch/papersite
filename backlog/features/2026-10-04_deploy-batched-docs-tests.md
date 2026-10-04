---
id: "2026-10-04_deploy-batched-docs-tests"
title: "Document and smoke-test batched deploy_volume.sh"
status: "Ready"
priority: "Medium"
created: "2026-10-04"
last_updated: "2026-10-04"
category: "features"
related_cips: ["0007"]
owner: "Neil Lawrence"
dependencies:
- "2026-10-04_deploy-batched-path"
tags:
- backlog
- deploy
- docs
- tests
---

# Task: Batched deploy docs and smoke tests (CIP-0007)

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs.

## Description

Document the batched/legacy deploy flags and add non-network smoke coverage:

- Update root `README.md` deploy section
- Update `.cursor/rules/publishing_workflow.mdc` if present
- Letter-count / dry-run tests on a small fixture tree (bats or `tests/` script)
- Manual dry-run note for large volumes before first real batched publish

## Acceptance Criteria

- [ ] README documents `--batched`, `--batch-threshold`, `--dry-run`, `--from-letter`
- [ ] Publishing workflow rule (if any) mentions batched mode for large volumes
- [ ] Automated dry-run/count test on a fixture with known `a`/`b` assets and posts
- [ ] No CI job auto-pushes to real volume remotes

## Implementation Notes

Prefer fixture under `tests/` over depending on a live v306 checkout in CI.

## Related

- CIP: 0007
- Depends on: `2026-10-04_deploy-batched-path`

## Progress Updates

### 2026-10-04

Task created as Ready when CIP-0007 was Accepted.
