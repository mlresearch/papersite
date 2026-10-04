---
id: "2026-10-04_document-mononym-authors"
title: "Document single-name (mononym) author encoding for posts and BibTeX"
status: "Ready"
priority: "Medium"
created: "2026-10-04"
last_updated: "2026-10-04"
category: "documentation"
related_cips: ["0009"]
owner: "Neil Lawrence"
dependencies: []
tags:
- backlog
- documentation
- authors
- mononym
- faq
- bibtex
---

# Task: Document mononym author encoding

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs.

## Description

Editors and authors correcting published `_posts` metadata need clear
guidance when a person uses a single name (e.g. Mausam). The public FAQ
already says author/title live in two fields, but not how to encode a
mononym. The proceedings spec requires “Lastname, Firstnames”, which
implies family-only for single names.

Document the canonical form in the FAQ (and any related editor-facing
notes), aligned with what `create_volume` / `splitauthors` already emit:

- YAML `author[]`: `family: Name` with empty/absent `given` (not
  `given: Name` with blank/missing family)
- `bibtex_author` / BibTeX: `Name,,` — not `{ }, {Name}` and not a bare
  `Name` in a Last, First list

Capture the v119 precedent (`garg20a` / PR mlresearch/v119#13) as the
worked example. Do **not** treat this task as the volume data cleanup;
follow-on work can fix remaining known posts (v180, v216) and tighten
`check_posts` if desired.

## Acceptance Criteria

- [ ] FAQ (proceedings.mlr.press / site source) states mononym encoding
      for both the display `author` field and the BibTeX/`bibtex_author`
      field
- [ ] Guidance matches PMLR spec “Lastname, Firstnames” and papersite
      generator behaviour (`lib/mlresearch.rb` `splitauthors`)
- [ ] Explicitly discourages `{ }, {Name}` and space-only `family: " "`
- [ ] Short cross-link or note from papersite docs/README or CIP-0009
      compression target if FAQ lives outside this repo
- [ ] Known remaining bad posts (v180, v216) listed as follow-on, not
      blocked on this docs task

## Implementation Notes

- FAQ source may live in `mlresearch.github.io` rather than papersite;
  update whichever repo owns `faq.html`.
- Optional later: warn in `check_posts` when `given` is set and `family`
  is blank (invert today’s lenient mononym allowance toward family-only).
- Optional later: fleet or one-off PRs for v180/v216 Mausam entries.

## Related

- CIP: 0009
- Example PR: https://github.com/mlresearch/v119/pull/13
- Spec: https://proceedings.mlr.press/spec.html (author “Lastname, Firstnames”)
- FAQ: https://proceedings.mlr.press/faq.html
- Code: `lib/mlresearch.rb` (`splitauthors`), `lib/tidy_bibtex.rb`
  (mononym `Name,,` notice), `lib/check_posts.rb` (author consistency)

## Progress Updates

### 2026-10-04

Task created after v119 mononym discussion: family-only is correct;
FAQ lacks guidance; local scan found remaining `given: Mausam` on v180
and v216.
