---
id: "2026-09-24_v316-citeproc-yaml-control-character"
title: "v316 citeproc.yaml unparseable: stray control character mid-abstract"
status: "Completed"
priority: "Medium"
created: "2026-09-24"
last_updated: "2026-09-24"
category: "bugs"
related_cips: []
owner: "Neil Lawrence"
dependencies: []
tags:
- backlog
- data-integrity
- citeproc
- unicode
---

# Task: v316 citeproc.yaml unparseable: stray control character mid-abstract

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs. Don't link directly to requirements (bottom-up pattern).

## Description

Found by the new live-data test in `tests/python/test_citeproc_yaml.py`
([CIP-0006](../../cip/cip0006.md) discusses moving checks like this closer
to each volume).

`https://proceedings.mlr.press/v316/assets/bib/citeproc.yaml` fails to
parse with PyYAML:

```
yaml.reader.ReaderError: unacceptable character #x0002: special characters
are not allowed
```

The offending text (in a paper abstract, near byte offset 221 in the raw
YAML) is:

```
...automated re\x02port generation. Many of the models deve...
```

A raw `U+0002` (STX, "Start of Text") control character is embedded
mid-word inside "report". This is almost certainly an artifact of how the
abstract text was originally extracted or pasted (e.g. from a PDF) into
the submitted BibTeX, and passed through the pipeline uncleaned.

## Acceptance Criteria

- [x] Root cause identified: which entry/entries in the `v316` BibTeX
      source contain the stray control character, and how many
      occurrences there are (this may not be the only one in the file).
      **Found 115 occurrences across all 27 papers in the volume** — a
      raw `0x02` (STX) byte wherever a word was hyphenated across a
      line-break in the original submitted PDF/BibTeX. Confirmed present
      in the original `.bib` (via git history), not introduced by
      `papersite`'s conversion pipeline.
- [x] Control character(s) stripped from the abstract text, corrected on
      the `v316` Jekyll post / `.bib` source on `gh-pages`.
- [ ] `tests/python/test_citeproc_yaml.py::test_citeproc_yaml_is_loadable[v316]`
      passes against the live site after the fix (pending GitHub Pages
      rebuild).
- [ ] Consider whether `papersite`'s BibTeX cleaning pipeline
      (`lib/tidy_bibtex.rb` / `check_volume.rb`) should gain a check that
      rejects non-printable control characters in abstracts/titles before
      a volume is published, so this class of error is caught pre-merge
      rather than post-publication. (Tracked as an option in CIP-0006;
      not implemented here.)

## Implementation Notes

- Reproduce locally:
  ```bash
  cd tests/python && source ../../.venv/bin/activate
  pytest test_citeproc_yaml.py -k v316 -v
  ```
- Worth grepping the whole `v316` `.bib` source for other non-printable
  characters (`[\x00-\x08\x0b\x0c\x0e-\x1f\x7f-\x9f]`) rather than fixing
  only the one instance the parser happened to stop on first.

## Related

- CIP: 0006 (proposes self-validating volume builds; this bug is the kind
  of thing that check would have caught before merge)
- Test: `tests/python/test_citeproc_yaml.py`

## Progress Updates

### 2026-09-24

Discovered via the new `tests/python/test_citeproc_yaml.py` suite while
validating that every volume's `citeproc.yaml` loads in Python. Filed as
a standalone data-integrity bug (Proposed) rather than blocking the test
suite itself.

Investigated all 115 occurrences across the volume's 27 posts (not just
the single one the YAML parser happened to stop on first). Each was
classified by hand as either:
- a mid-word PDF line-wrap with no real hyphen intended (104 cases,
  e.g. `informa\x02tion` → `information`), fixed by deleting the marker; or
- a genuine compound-word hyphen that happened to fall at a line-break
  (11 cases: `image-based`, `fine-tuned`, `single-cell`,
  `semi-automatic`, `structure-aware`, `annotation-free`,
  `tubule-centric`, `Top-attended`, `Lin-MIL`, `map-based`,
  `H&E-stained`), fixed by replacing the marker with `-`. The `Lin-MIL`
  case was cross-checked against another occurrence of the same model
  name later in the same abstract, already spelled correctly with a real
  hyphen, confirming the choice.

Verified every one of the 27 posts parses as valid YAML afterward and
diffed the full change set for any accidental word-joins. Pushed to
`gh-pages` (commit `dc24317`). Marking Completed; the
`tests/python/test_citeproc_yaml.py[v316]` case should pass once GitHub
Pages rebuilds the site.
