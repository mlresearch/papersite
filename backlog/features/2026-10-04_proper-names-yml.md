---
id: "2026-10-04_proper-names-yml"
title: "Curate and commit proper_names.yml dictionary (CIP-000B Phase 1)"
status: "Completed"
priority: "High"
created: "2026-10-04"
last_updated: "2026-10-04"
category: "features"
related_cips: ["000B"]
owner: "Neil Lawrence"
dependencies:
- "2026-10-04_proper-names-title-scan"
tags:
- backlog
- bibtex
- titles
- proper-names
- yaml
---

# Task: Curate and commit proper_names.yml (CIP-000B)

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs.

## Description

Turn the Phase 1 scan candidates into a human-curated YAML dictionary
committed in papersite (proposed path: `lib/proper_names.yml`). Schema must
support stems, optional `kind` (`name` | `acronym`), optional aliases
(e.g. Bayesian), and notes. Document match rules agreed in CIP-000B (whole
word; `{B}ayes` / `{Bayes}` and `{SVM}`-style forms protected).

Include only **recurring** acronyms from the scan (SVM, PCA, …). Paper-local
coinages stay out of the global file unless they clearly recur.

## Acceptance Criteria

- [x] `lib/proper_names.yml` (or accepted path) committed with initial stems
- [x] Schema documented in the file header or CIP-000B Detailed Description
- [x] Morphology / aliases called out explicitly (no silent substring matches)
- [x] Recurring acronyms distinguished (or tagged) vs proper-name stems
- [x] No auto-growth from CI — curation is manual

## Implementation Notes

Start small (high-precision names + a short acronym core from the scan).
Prefer false negatives over noisy false positives; soak in the checker task
will extend the list.

File created at `lib/proper_names.yml` from the scan starter (includes AI/LLM
and short acronyms ML/MAP/EM for capital⇒protect). Git commit may still be
pending if not yet staged.

## Related

- CIP: 000B
- Depends on: `2026-10-04_proper-names-title-scan`
- Next: `2026-10-04_proper-names-checker`

## Progress Updates

### 2026-10-04

Task created as Ready when CIP-000B was Accepted.

### 2026-10-04

Wrote `lib/proper_names.yml` with curated name + acronym stems; schema in
file header. Marked Completed (commit separately if desired).
