---
id: "2026-10-04_deploy-batched-path"
title: "Implement letter-batched deploy path in deploy_volume.sh"
status: "Ready"
priority: "High"
created: "2026-10-04"
last_updated: "2026-10-04"
category: "features"
related_cips: ["0007"]
owner: "Neil Lawrence"
dependencies:
- "2026-10-04_deploy-batched-flags-dry-run"
tags:
- backlog
- deploy
- batched
- gh-pages
---

# Task: Letter-batched deploy path (CIP-0007)

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs.

## Description

Implement the batched publish path in `bin/deploy_volume.sh`:

1. Assets → `main` only, letter by letter (+ push); honour `--from-letter`
2. Create/update `gh-pages` without leaving assets on that branch
3. Scaffolding commit once on `gh-pages` (Gemfile, `_config.yml`, `index.html`,
   volume README, PR template via `/bin/cp -f`)
4. Posts → `gh-pages` only, letter by letter (never commit posts to `main`)
5. Remove `.bib` from `gh-pages`; ensure `main` has volume README and no Jekyll/posts

Retain the legacy single-commit path when under threshold and not `--batched`.

## Acceptance Criteria

- [ ] Batched mode never commits `_posts/` to `main`
- [ ] After success, branch invariants from CIP-0007 hold
- [ ] `--from-letter` resumes without redoing earlier letters
- [ ] Progress lines per letter (`=== letter: N files ===` / `OK letter`)
- [ ] Legacy path still works for small volumes under threshold
- [ ] Volume README (not template) present on `main` after cleanup

## Implementation Notes

Encode v306 lessons from CIP-0007 Detailed Description. Serial letter pushes
only (no parallel). Do not implement fleet PR install (CIP-000A).

## Related

- CIP: 0007
- Depends on: `2026-10-04_deploy-batched-flags-dry-run`
- Next: `2026-10-04_deploy-batched-docs-tests`
- Prior completed deploy script task: `2025-10-07_new-deploy-script`

## Progress Updates

### 2026-10-04

Task created as Ready when CIP-0007 was Accepted.
