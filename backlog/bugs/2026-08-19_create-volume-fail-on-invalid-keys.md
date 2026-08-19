---
id: "2026-08-19_create-volume-fail-on-invalid-keys"
title: "create_volume.rb must fail on invalid BibTeX keys"
status: "Completed"
priority: "High"
created: "2026-08-19"
last_updated: "2026-08-19"
category: "bugs"
related_cips: []
owner: "Neil Lawrence"
dependencies: []
tags:
- backlog
- bibtex
- unicode
- create_volume
---

# Task: create_volume.rb must fail on invalid BibTeX keys

## Description

[papersite#2](https://github.com/mlresearch/papersite/issues/2) reports that
BibTeX entries whose keys contain invalid (including non-ASCII) characters are
silently omitted when `create_volume.rb` processes a volume. The paper never
appears in `_posts`, and the script can still exit 0.

`check_volume.rb` already errors on non-ASCII keys (see the `v328_original`
fixture: `miñoza26`, `schrödter26`). That check is optional: if an editor runs
`create_volume.rb` without it, the parser (`BibTeX.parse` in
`MLResearch.extractpapers`) still drops the entries without a hard failure.
That violates the data-integrity tenet: a missing paper is worse than a failed
run.

CIP-0001 made field values ASCII-only via `tidy_bib_unicode.rb`. Keys are a
different case: replacing characters inside a citekey would change the
identifier. The volume pipeline should refuse the input and name the bad keys,
so the editor can fix the `.bib` before generation.

## Acceptance Criteria

- [x] `create_volume.rb` / `MLResearch.extractpapers` exits non-zero if any
      `@inproceedings` key is non-ASCII or otherwise invalid.
- [x] The error lists every offending key (not only the first).
- [x] A volume whose keys are all ASCII still generates as today.
- [x] A test using `tests/fixtures/v328_original` (or an equivalent) fails the
      volume-creation path, not only `check_volume.rb`.
- [x] [papersite#2](https://github.com/mlresearch/papersite/issues/2) is closed
      once the check is in the generation path.

## Implementation Notes

- Reuse the key check already in `check_volume.rb`
  (`check_non_ascii_keys`) rather than duplicating a different regex.
  Calling that check from `create_volume.rb` before `BibTeX.parse` is enough
  if it raises or returns a non-zero status the script honours.
- Do not “fix” keys by running them through `tidy_bib_unicode.rb`. Citekeys
  must stay stable; the editor should rename `miñoza26` to `minoza26` (or
  similar) in the source `.bib`.
- After parse, a belt-and-braces comparison of source keys versus
  `bib['@inproceedings']` would also catch bibtex-ruby silently dropping
  entries for other invalid-key reasons (the related double-quote/`\"` case is
  already a `check_volume.rb` error).
- Keep `check_volume.rb` as the pre-publication gate; this task is about
  `create_volume.rb` not depending on that gate being run.

## Related

- GitHub: [mlresearch/papersite#2](https://github.com/mlresearch/papersite/issues/2)
- CIP-0001 (field Unicode tidying; does not cover keys)
- REQ-0001 (ASCII-only BibTeX before downstream processing)
- `lib/bibtex_keys.rb`
- `lib/check_volume.rb` (`check_non_ascii_keys`)
- `tests/test_create_volume_keys.sh`
- `tests/README.md` fixture `v328_original/`

## Progress Updates

### 2026-08-19

Task created as Proposed after the mlresearch issue triage. `check_volume.rb`
already rejects non-ASCII keys; `create_volume.rb` still does not.

Marked Ready and In Progress. Implementing a shared key check used by
`create_volume.rb` (before Unicode tidying) and `extractpapers`.

Implemented. Shared `lib/bibtex_keys.rb` is used by `check_volume.rb`,
`create_volume.rb` (before tidy), `create_reissue.rb`, and
`MLResearch.extractpapers` (plus a post-parse dropped-key check). Tests:
`test/test_bibtex_keys.rb` and `tests/test_create_volume_keys.sh`.
