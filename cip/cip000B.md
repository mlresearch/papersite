---
author: "Neil D. Lawrence"
created: "2026-10-04"
id: "000B"
last_updated: "2026-10-04"
status: "In Progress"
compressed: false
related_requirements: ["0003"]
related_cips: ["0001", "0003", "0008"]
tags:
- cip
- bibtex
- titles
- latex
- data-integrity
- pmlint
title: "Proper-name bracing in titles ({B}ayes, {M}arkov, …)"
---

# CIP-000B: Proper-name bracing in titles (`{B}ayes`, `{M}arkov`, …)

> **Note**: CIPs describe HOW to achieve requirements (WHAT).
> This CIP implements aspects of [REQ-0003](../requirements/req0003_bibtex-validation-prevents-pipeline-failures.md)
> (BibTeX validation prevents silent pipeline / citeproc failures).

## Status

- [x] Proposed - Initial idea documented
- [x] Accepted - Approved, ready to start work
- [x] In Progress - Actively being implemented
- [ ] Implemented - Work complete, awaiting verification
- [ ] Closed - Verified and complete
- [ ] Rejected - Will not be implemented
- [ ] Deferred - Postponed

## Summary

Add a curated list of proper names that commonly appear in ML/stats paper
titles (e.g. Bayes, Markov, Gaussian, Dirichlet) and a papersite checker that
ensures those names are LaTeX-protected when they should keep a capital letter
under title-case styles — typically `{B}ayes`, `{M}arkov`.

**Phase 1:** Scan existing volume titles (local `~/mlresearch/v*` / `r*` and/or
published indexes), propose candidate proper names, and commit a reviewed YAML
list under papersite.

**Phase 2:** Wire a checker into the intake lint path (`check_volume` /
`pmlint`) that reports unprotected occurrences against that list.

**Which requirements does this CIP address?** [REQ-0003](../requirements/req0003_bibtex-validation-prevents-pipeline-failures.md).

## Motivation

BibTeX/LaTeX bibliography styles often downcase title text. Proper names and
eponymous adjectives then lose required capitals unless the author braces the
capital letter (or the whole word). The failure mode is silent in the source
`.bib` and only shows up in rendered citations — classic
`data-integrity-over-convenience` territory.

Editors already fix these by hand (`{B}ayes`, `{M}arkov`, `{G}aussian`, …).
There is no shared list and no intake gate, so the same mistakes recur across
volumes. A small curated dictionary plus an early check catches the common
cases before conversion and publish.

Aligns with tenets: `data-integrity-over-convenience`,
`automation-with-guardrails`, `reproducible-auditable-pipeline`.

## Detailed Description

### What “protected” means

For a listed stem `Bayes`, any of these in a `title` (and optionally
`booktitle` / `series`) count as protected:

- `{B}ayes` / `{Bayes}` (preferred forms)
- Already-braced larger phrases that contain the stem with a capital B

Unprotected: bare `Bayes` or `bayes` where the dictionary says the capital
must be preserved. Exact matching rules (case, word boundaries, plurals,
adjectival forms) are fixed in Phase 1 when the YAML schema is written.

### Phase 1 — Scan and curated YAML

1. Collect title strings from available corpora (priority order):
   - Local volume BibTeX / `_posts` under `~/mlresearch/v*` and `r*`
   - Optionally site-wide indexes later (not required for v1)
2. Tokenise titles; surface capitalised tokens and already-braced forms
   (`{X}…`, `{Word}`) as candidate proper names **and acronyms**.
3. Human-curate into a YAML file in papersite, e.g.
   `lib/proper_names.yml` (final path chosen at acceptance), with at least:
   - `stem` / match key (e.g. `Bayes`, `SVM`)
   - optional `kind` (`name` | `acronym`) for reporting clarity
   - optional notes / examples
   - optional flags (e.g. allowlist of forms that must *not* be flagged)
4. Commit the YAML as the source of truth; extend it surgically when new
   recurring names appear (no silent auto-growth in CI).

**Design constraint:** the scanner *proposes*; humans *approve*. The checker
never invents new dictionary entries at lint time.

### Acronyms (scan tricks + what enters the dictionary)

Titles also need bracing for **acronyms** (`{SVM}`, `{PCA}`, …). Two
populations:

1. **Recurring community acronyms** (SVM, PCA, MCMC, …) — treat like
   proper-name stems: high corpus frequency → candidates for the curated
   YAML; checker enforces them the same way (protected if braced).
2. **Paper-local coinages** — authors invent `WXYZ` for one paper. These
   dominate the long tail; dumping every all-caps token into the global
   dictionary would be noisy and unfair to other volumes.

**Scan heuristics (Phase 1 report buckets, not auto-dictionary):**

| Signal | Intent |
|--------|--------|
| Whole-word `/[A-Z]{2,}/` (and optional `[A-Z]{2,}s` plurals) | Candidate acronyms |
| Already-braced `{SVM}` / `{S}VM` | Evidence the community/editor already protects the form |
| Definition pattern, e.g. `... (SVM)` / `SVM (... )` after a phrase | Paper-local coinage — report separately |
| Frequency across many volumes/keys | Promote to curated YAML; hapax/rare stay in “local only” report |

Regex shapes are starting points for the scanner; tune against the soak
corpus. **v1 checker still only flags stems listed in YAML** — the regex
pass is for curation and optional later “warn on unknown all-caps” work,
not a silent global require-brace-all-acronyms rule.

### Phase 2 — Checker in papersite scripts

1. Load `proper_names.yml` in Ruby (same stack as `check_volume` /
   `tidy_bibtex`).
2. Add a check (preferred home: `lib/check_volume.rb`, surfaced via
   `bin/pmlint` / CIP-0008 intake composition) that:
   - Parses or scans `title` fields (and decide at acceptance whether
     `booktitle` is in scope for v1)
   - For each dictionary stem, flags unprotected occurrences with key +
     line/context
   - Defaults to **error** on unprotected stems for new intake; document
     any warn-only exceptions
3. **Out of scope for v1 unless accepted explicitly:**
   - Auto-fix rewriting titles to insert braces
   - Posts-mode (`check_posts`) title checks (can follow once intake is
     stable; fleet rollout of any new behaviour stays CIP-000A)
   - Full NLP / named-entity recognition

### Policy decisions to freeze at Accepted

| Topic | Options | Lean for v1 |
|-------|---------|-------------|
| Severity | warn vs error | **error** at intake |
| Forms | `{B}ayes` only vs also `{Bayes}` | accept **both** as protected |
| Boundaries | whole word only | **whole word** (no match inside unrelated tokens) |
| Morphology | `Bayesian`, `Markovian` | separate stems or explicit aliases in YAML |
| Acronyms in YAML | recurring only vs all scanned caps | **recurring only** (incl. high-freq AI/LLM); local coinages stay scan-only |
| Unknown all-caps at lint | ignore vs warn | **ignore** in v1 (YAML stems only) |
| High-freq acronyms | exclude to reduce lint noise vs include | **include** if capitalised form should be preserved |
| Auto-fix | none vs `--fix` | **none** in v1 (report only) |
| Posts path | intake only vs also `check_posts` | **intake only** in v1 |

### Relationship to other CIPs

| CIP | Relation |
|-----|----------|
| CIP-0003 | Title brace *balance* already reported; this CIP is about *semantic* bracing of known names |
| CIP-0008 | Checker runs as part of intake `pmlint --check` composition |
| CIP-0001 | Unicode tidying remains separate; proper-name bracing is ASCII/LaTeX structure |
| CIP-000A | Only if we later need to ship new workflow bits; v1 is papersite-local |

## Implementation Plan

1. **Phase 1 — Corpus scan + YAML**
   - Script (papersite `bin/` or one-off under `cip/cip000B/`) to extract
     title tokens, braced capitals, and acronym-shaped tokens from local
     volumes (with frequency + definition-pattern buckets)
   - Produce candidate lists (names vs recurring acronyms vs local-only)
     + curated `lib/proper_names.yml`
   - Document schema and curation rules in this CIP (update after review)

2. **Phase 2 — Checker**
   - Implement check in `lib/check_volume.rb` (or small helper loaded from it)
   - Hook into `pmlint` intake so CI sees failures
   - Fixtures: protected OK; unprotected Bayes/Markov fail; word-boundary
     negatives; braced forms pass

3. **Docs / compression (after Closed)**
   - Short editor note (FAQ or papersite README) pointing at the bracing
     convention and the dictionary

## Backward Compatibility

- Existing published volumes are not rewritten by v1.
- Stricter intake may reject submissions that previously passed; that is
  intentional. Editors fix titles (or, rarely, extend the YAML after review).
- No change to deploy/branch layout.

## Testing Strategy

- Unit/fixture tests beside `check_volume` / `pmlint` tests for each policy
  row above.
- Soak: run the checker over a sample of local `v*`/`r*` BibTeX; triage
  false positives into YAML aliases or match-rule tweaks before treating
  severity as final.
- No network required for the checker itself (dictionary is in-repo).

## Related Requirements

- [REQ-0003](../requirements/req0003_bibtex-validation-prevents-pipeline-failures.md) —
  validation prevents silent BibTeX / citeproc failures.

## Implementation Status

- [x] Phase 1: title scan — [`2026-10-04_proper-names-title-scan`](../backlog/features/2026-10-04_proper-names-title-scan.md)
- [x] Phase 1: curated YAML — [`lib/proper_names.yml`](../lib/proper_names.yml) / [`2026-10-04_proper-names-yml`](../backlog/features/2026-10-04_proper-names-yml.md)
- [x] Phase 2: checker — [`2026-10-04_proper-names-checker`](../backlog/features/2026-10-04_proper-names-checker.md)
- [ ] Phase 2: fixtures + soak — [`2026-10-04_proper-names-tests-soak`](../backlog/features/2026-10-04_proper-names-tests-soak.md) (fixtures done; broader soak optional)
- [ ] Editor-facing note — [`2026-10-04_proper-names-editor-note`](../backlog/documentation/2026-10-04_proper-names-editor-note.md)

## References

- BibTeX title-case / brace protection (common style-file behaviour)
- Related tooling: `lib/check_volume.rb`, `lib/tidy_bibtex.rb` (unmatched
  braces), `bin/pmlint` (CIP-0008)
- Tenets: `data-integrity-over-convenience`, `automation-with-guardrails`
