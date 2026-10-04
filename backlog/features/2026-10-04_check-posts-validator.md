---
id: "2026-10-04_check-posts-validator"
title: "Implement check_posts validator (YAML parse, schema, consistency, non-printables)"
status: "Ready"
priority: "High"
created: "2026-10-04"
last_updated: "2026-10-04"
category: "features"
related_cips: ["0009"]
owner: "Neil Lawrence"
dependencies: []
tags:
- backlog
- pmlint
- yaml
- posts
- check-posts
---

# Task: Implement check_posts validator (CIP-0009)

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs.

## Description

Add `lib/check_posts.rb` (name flexible) that validates Jekyll paper posts under `_posts/`:

1. Split / parse YAML frontmatter; fail on invalid YAML or broken `---` fences
2. Enforce the paper frontmatter contract (required keys/shapes from CIP-0005 / `extractpapers`)
3. Within-post consistency: display `author`/`title` vs `bibtex_author` / `tex_title` when those snapshot fields exist
4. Reject non-printable / bad UTF-8 in string fields (CIP-0006 class, at post level)

Read-only: report errors with file + field; exit non-zero on failure. No auto-rewrite in v1.

## Acceptance Criteria

- [ ] Library/CLI can scan a `_posts/` directory and exit `0`/`1`
- [ ] Invalid YAML and missing required keys produce actionable errors
- [ ] Wrong `extras` / `author` shapes fail; optional keys may be absent
- [ ] Consistency checks run only when BibTeX snapshot fields are present
- [ ] Non-printable characters in text fields fail the check
- [ ] Does not require a `.bib` file on the volume

## Implementation Notes

Reuse patterns from `lib/check_volume.rb` for reporting. Schema ground truth: CIP-0005 frontmatter table and `lib/mlresearch.rb` output shape. Normalisation for author/title match should be documented in code comments briefly.

## Related

- CIP: 0009
- Next: `2026-10-04_pmlint-posts-mode`, `2026-10-04_check-posts-tests`

## Progress Updates

### 2026-10-04

Task created as Ready when CIP-0009 was Accepted.
