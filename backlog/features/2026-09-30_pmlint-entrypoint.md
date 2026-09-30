---
id: "2026-09-30_pmlint-entrypoint"
title: "Add bin/pmlint with papersite self-update"
status: "Ready"
priority: "High"
created: "2026-09-30"
last_updated: "2026-09-30"
category: "features"
related_cips: ["0008"]
owner: "Neil Lawrence"
dependencies: []
tags:
- backlog
- pmlint
- self-update
---

# Task: Add bin/pmlint with papersite self-update (CIP-0008)

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs.

## Description

Create the `pmlint` entrypoint (`bin/pmlint`, thin shell wrapper and
optional small orchestrator) that resolves `PAPERSITE_ROOT`, updates
the papersite clone from source (unless `PMLINT_SKIP_UPDATE=1`), and is
ready to invoke composed check/fix steps.

Self-update contract (from CIP-0008):

1. `PAPERSITE_ROOT` if set
2. Else sibling `../papersite`
3. Else clone/cache path as documented
4. `git fetch` + fast-forward default branch; fail clearly on dirty tree
   unless skip-update is set
5. Invoke tools only from the refreshed tree

## Acceptance Criteria

- [ ] `bin/pmlint` exists and shows usage / help
- [ ] Resolves `PAPERSITE_ROOT` per CIP-0008 order
- [ ] Self-update runs by default; `PMLINT_SKIP_UPDATE=1` skips it
- [ ] Dirty papersite tree fails with a clear message (when update required)
- [ ] README has a short `pmlint` usage section
- [ ] Does not yet need full check/fix composition (that is the next task),
      but should accept `--check` / `--fix` and volume args without crashing
      (stub or wire if dry-run already landed)

## Implementation Notes

Prefer the smallest wrapper. Do not vendor papersite into volume repos.
In CI, checkout of papersite + `PAPERSITE_ROOT` satisfies self-update.

## Related

- CIP: 0008
- Next: `2026-09-30_pmlint-check-fix`

## Progress Updates

### 2026-09-30

Task created as Ready when CIP-0008 was Accepted.
