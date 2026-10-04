---
id: "2026-10-04_proper-names-title-scan"
title: "Scan local volume titles for candidate proper names (CIP-000B Phase 1)"
status: "Completed"
priority: "High"
created: "2026-10-04"
last_updated: "2026-10-04"
category: "features"
related_cips: ["000B"]
owner: "Neil Lawrence"
dependencies: []
tags:
- backlog
- bibtex
- titles
- proper-names
- acronyms
- scan
---

# Task: Scan local volume titles for candidate proper names (CIP-000B)

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs.

## Description

Run a reproducible scan over local `~/mlresearch/v*` / `r*` titles (BibTeX
`title` fields and/or `_posts` display titles) to propose candidates that
often need LaTeX bracing:

- Proper names / eponyms (`{B}ayes`, `{M}arkov`, …)
- **Acronyms** — both recurring ones (`{SVM}`, `{PCA}`) and paper-local
  coinages

Output reviewable candidate reports (e.g. under `cip/cip000B/`) with token,
occurrence count, sample titles, braced-form evidence, and a **bucket**
(name vs recurring-acronym vs local-acronym). The scanner proposes; it does
not write the curated YAML.

### Acronym detection tricks

Use regex / pattern buckets (tune on the corpus; starting points):

- Whole-word all-caps: `\b[A-Z]{2,}\b` (optional plural `s`)
- Already protected: `\{[A-Z]{2,}\}` or `\{[A-Z]\}[A-Z]+`
- Definition-ish: `([A-Z]{2,})` after a phrase, or `Acronym (Expansion)` /
  `Expansion (Acronym)` — mark as likely paper-local
- Cross-volume frequency: high → promote toward curated YAML; hapax/rare →
  keep in local-only report (do not dump into the global dictionary)

## Acceptance Criteria

- [x] Script or one-off under papersite/`cip/cip000B/` scans local volumes
      without network
- [x] Reports capitalised name tokens and existing `{X}…` / `{Word}` forms
      with counts and examples
- [x] Separately reports acronym-shaped tokens with frequency + sample
      titles, bucketed recurring vs local/hapax where possible
- [x] Seed name list includes obvious stems (Bayes, Markov, Gaussian, …)
      when present in the corpus
- [x] Results are reviewable (markdown or YAML candidates) before curation

## Implementation Notes

Prefer reading BibTeX `title` at volume roots; `_posts` `title` can
supplement. Keep the tool out of the default `pmlint` path — Phase 1 only.
v1 checker (later task) still enforces **YAML stems only**; regex here is
for curation, not a require-brace-all-caps lint rule.

## Related

- CIP: 000B
- Next: `2026-10-04_proper-names-yml`

## Progress Updates

### 2026-10-04

Task created as Ready when CIP-000B was Accepted.

### 2026-10-04

Updated: acronym scan buckets + regex heuristics per CIP-000B discussion.

### 2026-10-04

Ran local scan (~38k titles). Reports under `cip/cip000B/` including
`SCAN_SUMMARY.md`. Mid-title Capitals from `_posts` too noisy for auto-YAML;
curated dictionary landed at `lib/proper_names.yml`.
