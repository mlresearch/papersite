---
id: "2026-10-04_pmfleet-apply-status"
title: "Implement pmfleet apply --open-prs and status"
status: "Ready"
priority: "High"
created: "2026-10-04"
last_updated: "2026-10-04"
category: "features"
related_cips: ["000A"]
owner: "Neil Lawrence"
dependencies:
- "2026-10-04_pmfleet-inventory-plan"
tags:
- backlog
- fleet
- pmfleet
- pull-requests
---

# Task: pmfleet apply / status (CIP-000A)

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs.

## Description

Extend the fleet tool with mutating and progress subcommands:

- `apply --campaign <id> --open-prs` — create branch + PR per missing
  (and allowed) repo; refuse to run without the explicit flag
- `status --campaign <id>` — progress vs last inventory (PR open / merged
  / still missing)

Invariants from CIP-000A: no `push --force` to `main`/`gh-pages`;
rate-limit PR creation; resume-safe; never overwrite `custom` unless the
campaign defines a merge strategy.

## Acceptance Criteria

- [ ] `apply` without `--open-prs` (or equivalent) refuses to mutate
- [ ] Changes land only via branch + PR
- [ ] Re-run skips repos already PR’d or merged
- [ ] `custom` / `skip` repos are not clobbered by default
- [ ] `status` summarises remaining gap

## Implementation Notes

Prefer `gh pr create`. Integration test against throwaway/local bare
remotes before any bulk run on mlresearch volumes.

## Related

- CIP: 000A
- Depends on: `2026-10-04_pmfleet-inventory-plan`
- Used by: campaign backlog tasks for posts/intake

## Progress Updates

### 2026-10-04

Task created as Ready when CIP-000A was Accepted.
