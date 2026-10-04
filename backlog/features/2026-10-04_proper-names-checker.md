---
id: "2026-10-04_proper-names-checker"
title: "Add proper-name bracing check to check_volume / pmlint intake (CIP-000B Phase 2)"
status: "Completed"
priority: "High"
created: "2026-10-04"
last_updated: "2026-10-04"
category: "features"
related_cips: ["000B"]
owner: "Neil Lawrence"
dependencies:
- "2026-10-04_proper-names-yml"
tags:
- backlog
- bibtex
- titles
- proper-names
- check-volume
- pmlint
---

# Task: Proper-name bracing checker in intake lint (CIP-000B)

## Description

Load the curated proper-name YAML and check BibTeX `title` fields for
unprotected stems. Warn on unknown all-caps acronyms (regex) with a YAML
snippet and optional `--add-proper-names` interactive append.

## Acceptance Criteria

- [x] Unprotected dictionary stems in `title` fail intake check (error)
- [x] `{B}ayes` and `{Bayes}` (and `{SVM}`) count as protected
- [x] Whole-word matching only
- [x] Runs via `check_volume` / `pmlint --check`
- [x] Unknown acronyms warn + suggest YAML; `--add-proper-names` can append
- [x] Does not rewrite BibTeX titles

## Related

- CIP: 000B
- Next: `2026-10-04_proper-names-tests-soak`

## Progress Updates

### 2026-10-04

Implemented in `lib/check_volume.rb` (`check_proper_name_bracing`).
