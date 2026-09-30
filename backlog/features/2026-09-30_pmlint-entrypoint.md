---
id: "2026-09-30_pmlint-entrypoint"
title: "Add bin/pmlint with install, always-auto-update, and PATH shim"
status: "Completed"
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
- install
---

# Task: Add bin/pmlint with install and always-auto-update (CIP-0008)

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs.

## Description

Create the `pmlint` entrypoint and first-time install path so volume
editors install once, then every run updates papersite from source
automatically before checks.

### Self-update (every run)

Unless `PMLINT_SKIP_UPDATE=1`:

1. Resolve `PAPERSITE_ROOT` (`PAPERSITE_ROOT` env → sibling `../papersite`
   → install/cache clone)
2. `git fetch origin` on default branch (`main`)
3. If local HEAD is behind `origin/main`, fast-forward
4. If already up to date, continue
5. If dirty and cannot update, fail with a clear message (no silent stale run)
6. Run tools only from that refreshed tree

### Install (once)

Idempotent installer (`bin/install-pmlint` or equivalent documented
one-liner) that:

- Clones `mlresearch/papersite` into the cache path if missing
- Installs a `pmlint` shim on `PATH` (e.g. `~/.local/bin/pmlint`)
- Re-running install refreshes the shim / ensures the clone exists
- README documents: install → `cd vNNN` → `pmlint --check NNN`

Sibling-clone developers may call `../papersite/bin/pmlint` directly;
that path still self-updates each run.

## Acceptance Criteria

- [x] `bin/pmlint` exists and shows usage / help
- [x] Resolves `PAPERSITE_ROOT` per CIP-0008 order
- [x] Every run fetches and fast-forwards when behind (default)
- [x] Already-up-to-date is a quiet no-op after fetch
- [x] Dirty tree that blocks update fails clearly
- [x] `PMLINT_SKIP_UPDATE=1` skips update (offline/dev/CI fixtures)
- [x] Installer clones cache path if needed and places PATH shim
- [x] Installer is idempotent (safe to re-run)
- [x] README documents install + `pmlint --check` / `--fix`
- [x] Stub or wire `--check` / `--fix` / volume args without crashing
      (full compose is `2026-09-30_pmlint-check-fix`)

## Implementation Notes

Prefer the smallest wrapper. Do not vendor papersite into volume repos.
In CI, checkout of papersite + `PAPERSITE_ROOT` (+ usually skip-update)
satisfies the contract.

## Related

- CIP: 0008
- Next: `2026-09-30_pmlint-check-fix`

## Progress Updates

### 2026-09-30

Task created as Ready when CIP-0008 was Accepted.

Clarified: install + always-auto-update (fetch; FF when behind) are
in scope for this task, not optional docs-only.

Shipped `bin/pmlint`, `bin/install-pmlint`, self-update, and README
install docs. Marked Completed as part of CIP-0008 v1.
