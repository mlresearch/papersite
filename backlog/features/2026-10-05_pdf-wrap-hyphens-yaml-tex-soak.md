---
id: "2026-10-05_pdf-wrap-hyphens-yaml-tex-soak"
title: "PDF wrap hyphens: YAML lists, TeX join confidence, UAI soak"
status: "Completed"
priority: "High"
created: "2026-10-05"
last_updated: "2026-10-05"
category: "features"
related_cips: ["0006", "0008"]
owner: "Neil Lawrence"
dependencies: []
tags:
- backlog
- check-volume
- tidy-bibtex
- data-integrity
- bibtex
- pdf-extraction
---

# Task: PDF wrap hyphens — YAML lists, TeX join confidence, UAI soak

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs.

## Description

Follow-on for PDF line-wrap hyphen detection/repair (`letter- lowercase`
artifacts such as `knowl- edge` / `state- of-the-art`):

1. Keep curated join/keep lists editable in YAML (same pattern as
   `lib/proper_names.yml`), not hardcoded Ruby arrays.
2. Optionally use TeX English hyphenation patterns (`hyph-en-us.tex`) as
   a high-confidence **join** signal when `left+right` is a single word
   broken at a legal hyphenation point — without replacing the
   compound-right keep list.
3. Soak recent UAI reissue BibTeX (`lawrennd/r9`–`r16` / `uai2011`–
   `uai2018`), expand YAML from false joins/keeps, then apply
   `pmlint --fix` (or `tidy_bibtex --fix-wrap-hyphens`) surgically.

Detection and `--fix-wrap-hyphens` / `pmlint --fix` wiring already
landed; this task finishes the curation pipeline and volume cleanup.

## Acceptance Criteria

- [x] `lib/pdf_wrap_hyphens.yml` holds `function_left` and
      `compound_right`; Ruby loads from YAML only
- [x] Optional TeX-pattern join helper documented and gated (no silent
      dependency on a local TeX Live tree; fail open to current rules)
- [x] UAI r9–r16 soak: sample false joins/keeps, extend YAML, apply fix
      in reissue repos with reviewable diffs
- [x] Regression coverage for YAML load failure and at least one TeX-
      assisted join case (if TeX path ships)

## Implementation Notes

- **YAML**: mirror the `proper_names.yml` curation style — comments
  explain when to add a `compound_right` token (`occurrence` for
  `co- occurrence` → `co-occurrence`) vs relying on default join
  (`co- ordinate` → `coordinate`).
- **TeX patterns**: Vendored full US English `hyph-en-us` pat/hyp under
  `lib/hyphenation/` (~31KB). Liang marks legal break points inside
  words; they do not encode compounds. TeX only biases toward **join**
  (and can override `function_left`); YAML `compound_right` still wins
  for keeps. No TeX Live required at runtime.
- **Soak**: start with `uai2018.bib` (~700 hits); watch `co-*`,
  `multi-*`, `re-*`, `non-*`, and function-word lefts. Do not bulk-
  commit reissue repos without per-volume review.

## Related

- CIP: 0006 (intake rejection of PDF extraction artifacts; same family as
  non-printables / ligatures), 0008 (`pmlint --fix` includes
  `--fix-wrap-hyphens`)
- Code: `lib/pdf_wrap_hyphens.rb`, `lib/pdf_wrap_hyphens.yml`,
  `lib/tex_hyphenator.rb`, `lib/hyphenation/`, `lib/check_volume.rb`,
  `lib/tidy_bibtex.rb`, `bin/pmlint`
- Fixtures: `tests/fixtures/pdf_wrap_hyphens/`

## Progress Updates

### 2026-10-05

Task created. Moved `function_left` / `compound_right` out of Ruby
constants into `lib/pdf_wrap_hyphens.yml`; loader raises if the file is
missing or malformed.

TeX join confidence landed:
- Vendored `lib/hyphenation/hyph-en-us.{pat,hyp}.txt` (+ NOTICE)
- `lib/tex_hyphenator.rb` — Liang patterns, US left/right mins 2/3
- Decision order: compound_right → TeX join → function_left → default
  join. TeX overrides bad `function_left` drops (`in- variant` →
  `invariant`) but does not override YAML keeps (`semi- supervised`).
  Missing patterns / `PMLR_DISABLE_TEX_HYPHEN=1` fail open.
- Tests: `tests/test_tex_hyphenator.rb` (wired in
  `.github/workflows/test-pmlint.yml`)

UAI soak applied and committed in `lawrennd/r9`, `r11`–`r16` (r10 had
no ASCII wrap hyphens; soft hyphens there are unicode-tidy). Edge cases
from soak folded back into YAML/decision logic (`ity---` vs `of-`,
`forms` vs `form`, `known`). Task criteria complete pending any further
false positives found at volume publish time.
