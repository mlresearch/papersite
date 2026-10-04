---
id: "2026-10-04_pmlint-posts-pr-ci"
title: "Add example GitHub Actions workflow for pmlint posts on _posts PRs"
status: "Ready"
priority: "Medium"
created: "2026-10-04"
last_updated: "2026-10-04"
category: "infrastructure"
related_cips: ["0009", "0004"]
owner: "Neil Lawrence"
dependencies:
- "2026-10-04_pmlint-posts-mode"
tags:
- backlog
- pmlint
- github-actions
- ci-cd
- posts
---

# Task: Example workflow for pmlint posts on PRs (CIP-0009)

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs.

## Description

Add an example (or extend `pmlint-volume-example.yml`) so volume repos can run **posts** checks on pull requests that touch `_posts/**`. Checkout papersite, set `PAPERSITE_ROOT`, run `pmlint posts --check`. Document enablement in README; point FAQ correction editors at the local command.

Fleet install into every existing volume repo is **out of scope** (separate CIP later).

## Acceptance Criteria

- [ ] Example workflow under papersite `.github/` for posts mode
- [ ] Path filter (or equivalent) so job targets `_posts` correction PRs
- [ ] Job fails when posts lint fails
- [ ] README documents how a volume enables the workflow
- [ ] Intake-only example behaviour for unpublished volumes remains clear

## Implementation Notes

Published volumes often keep `_posts` on `gh-pages`; workflow docs must say which branch to run on. Prefer checking out the PR head as Actions normally does. No deploy, no `create_volume`.

## Related

- CIP: 0009, 0004
- Depends on: `2026-10-04_pmlint-posts-mode`

## Progress Updates

### 2026-10-04

Task created as Ready when CIP-0009 was Accepted.
