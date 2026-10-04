---
id: "2026-10-04_check-posts-mononym-family"
title: "Tighten check_posts mononym rule to prefer family-only authors"
status: "Ready"
priority: "Medium"
created: "2026-10-04"
last_updated: "2026-10-04"
category: "features"
related_cips: ["0009"]
owner: "Neil Lawrence"
dependencies:
- "2026-10-04_document-mononym-authors"
tags:
- backlog
- check_posts
- authors
- mononym
- validation
---

# Task: Tighten check_posts mononym family preference

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs.

## Description

`lib/check_posts.rb` currently allows blank `family` when `given` is
present (comment: mononyms / org names). That matches lenient historical
posts but diverges from the generator (`splitauthors`) and BibTeX
convention, which put a single name in **family** and emit `Name,,`.

After FAQ/docs establish family-only as the official form, update the
validator so new or edited posts prefer that shape:

1. Prefer / require mononyms as `family: Name` with empty/absent `given`
2. Treat `given: Name` + blank `family` as a warning or error (policy TBD)
3. Keep `bibtex_author` consistency: family token (or, for legacy, given)
   must appear in the BibTeX name string; mononym BibTeX remains `Name,,`

Org / literal names (`literal:`) should remain accepted if already
supported; do not force them through the family field incorrectly.

## Acceptance Criteria

- [ ] Decision recorded: warn vs error for inverted mononym
      (`given` set, `family` blank)
- [ ] `check_posts` implements that decision with a clear message pointing
      at family-only + `Name,,`
- [ ] Unit/fixture coverage for: correct mononym, inverted mononym,
      normal Given/Family, and bibtex `Name,,` consistency
- [ ] Existing soak / known-bad volumes (e.g. v180, v216) either fixed
      first or explicitly allowlisted / graded so CI does not surprise
- [ ] Docs task `2026-10-04_document-mononym-authors` linked or completed
      so editor-facing guidance matches the checker

## Implementation Notes

Relevant code today (`lib/check_posts.rb`):

- Author map check allows blank family when given present
- Bibtex consistency uses `fam.empty? ? given : fam` as the match token

Suggested approach:

1. Add a dedicated check (or extend the author loop) for inverted mononym
2. Prefer **warn** first if fleet cleanup is incomplete; promote to
   **error** once remaining posts are fixed
3. Align messages with FAQ wording once published

Follow-on data cleanup (separate or same PR series): v180, v216 Mausam
posts still use `given: Mausam`.

## Related

- CIP: 0009
- Depends on docs: `backlog/documentation/2026-10-04_document-mononym-authors.md`
- Example fix: https://github.com/mlresearch/v119/pull/13
- Code: `lib/check_posts.rb`, `lib/mlresearch.rb` (`splitauthors`),
  `lib/tidy_bibtex.rb`

## Progress Updates

### 2026-10-04

Task created as the validator follow-up to the mononym documentation
backlog; current checker is intentionally lenient the wrong way for
single-name authors.
