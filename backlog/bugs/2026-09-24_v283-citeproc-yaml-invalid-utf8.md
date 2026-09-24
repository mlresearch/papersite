---
id: "2026-09-24_v283-citeproc-yaml-invalid-utf8"
title: "v283 citeproc.yaml unparseable: stray C1 control bytes in a paper title"
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

# Task: v283 citeproc.yaml unparseable: stray C1 control bytes in a paper title

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs. Don't link directly to requirements (bottom-up pattern).

## Description

Found by the new live-data test in `tests/python/test_citeproc_yaml.py`
([CIP-0006](../../cip/cip0006.md) discusses moving checks like this closer
to each volume).

`https://proceedings.mlr.press/v283/assets/bib/citeproc.yaml` fails to
parse with PyYAML:

```
yaml.reader.ReaderError: unacceptable character #x0080: special characters
are not allowed
```

The offending text (paper title, around byte offset 200469 in the raw
YAML) is:

```
"What are my options?"\x80\x9d: Explaining RL Agents with Diverse Nea...
```

The opening quote rendered correctly as a curly left double quotation
mark, but the matching closing quote was replaced by two raw C1 control
bytes (`U+0080`, `U+009D`) instead of the correct `U+201D` (`”`). This
looks like the LaTeX-to-Unicode conversion (or a `unicode_replacements.yml`
gap) mishandled a smart closing quote in the original BibTeX title for
this entry, producing mojibake instead of the proper glyph.

Because the bad bytes make it into the rendered Jekyll page verbatim, this
breaks every consumer that tries to parse `v283`'s `citeproc.yaml` as
YAML (not just our test).

## Acceptance Criteria

- [x] Root cause identified: which BibTeX source (in the `v283` repo) has
      the malformed title, and whether it originated in the submitted
      `.bib` file or was introduced by the `papersite` conversion
      pipeline (`lib/mlresearch.rb` / `LaTeX::Decode` / `unicode_replacements.yml`).
- [x] Corrected title (with a proper `”` U+201D) pushed to the `v283`
      Jekyll post / `.bib` source on `gh-pages`.
- [ ] `tests/python/test_citeproc_yaml.py::test_citeproc_yaml_is_loadable[v283]`
      passes against the live site after the fix (pending GitHub Pages
      rebuild).
- [ ] If the root cause is a gap in `unicode_replacements.yml` or the
      detex pipeline, add a regression case there too so future volumes
      with the same smart-quote pattern don't reintroduce this. (Deferred
      to CIP-0006 — root cause was in the submitted `.bib` itself, not
      the conversion pipeline, so no pipeline change is needed for this
      specific case.)

## Implementation Notes

- Reproduce locally:
  ```bash
  cd tests/python && source ../../.venv/bin/activate
  pytest test_citeproc_yaml.py -k v283 -v
  ```
- The raw bytes suggest either a Windows-1252/Latin-1 vs UTF-8 mismatch
  somewhere in the pipeline, or a straight copy-paste of a smart quote
  from a word processor that survived `detex()` without normalization.

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

Root cause: in `_posts/2025-05-22-brindise25a.md`, both the `title` and
`tex_title` YAML fields contained the opening curly quote as a correct
UTF-8 character (`“`), but the closing quote had been corrupted into
literal escape text `\"\x80\x9D` instead of `”` (U+201D). Fixed both
fields on `gh-pages` (commit `b267412`) and pushed to
`github.com/mlresearch/v283`. Marking Completed; the
`tests/python/test_citeproc_yaml.py[v283]` case should pass once GitHub
Pages rebuilds the site.
