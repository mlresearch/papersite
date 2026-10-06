# PMLR Repository

[![Tests](https://github.com/mlresearch/papersite/workflows/Test%20BibTeX%20Cleaner/badge.svg)](https://github.com/mlresearch/papersite/actions)

This repository contains tools and scripts for managing and publishing proceedings for the Proceedings of Machine Learning Research (PMLR).

*I've archived an old version of this code at <https://github.com/mlresearch/old_papersite>. On 2025-05-26 that repo was cloned to start this one and restructure with aim of creating a better automated pipeline.*

## Overview

The repository is structured as follows:

- **lib/**: Contains Ruby scripts for managing the Jekyll site and processing BibTeX files.
- **bin/**: Contains shell scripts for various tasks related to the repository.
- **backlog/**: Task management system for tracking improvements and features.
- **cip/**: Code Improvement Plans for documenting architectural changes.

## Volume Processing Workflow

Prefer **`pmlint`** for pre-publication validation (and optional safe BibTeX fixes).
It self-updates papersite from source on each run, then composes the existing
tidy + `check_volume` checks.

### Install `pmlint` (once)

```bash
# From a papersite checkout:
bash bin/install-pmlint
# Ensure ~/.local/bin is on PATH
export PATH="$HOME/.local/bin:$PATH"
pmlint --help
```

Or call the script directly from a sibling clone (still self-updates):

```bash
cd ~/mlresearch/v304
../papersite/bin/pmlint --check          # id inferred from directory name (v304)
../papersite/bin/pmlint --check r0       # rerelease repos use rNNN
```

### Lint a volume

```bash
cd ~/mlresearch/v304
pmlint --check              # read-only; exit 1 on failure (use in PRs)
pmlint --fix               # escape %, wrap hyphens, \\textbackslash → \\, then re-check
PMLINT_SKIP_UPDATE=1 pmlint --check   # offline / dirty papersite tree
```

Volume id is inferred from the repo/directory name (`v350`, `r0`, `r201`, …).
A bare number still works (`304` → `v304`).
`--check` must not modify the volume tree. `--fix` only applies non-interactive
`tidy_bibtex --fix-percent --fix-wrap-hyphens --fix-textbackslash`
(not Unicode map edits or PDF moves).

If the volume already has a **gh-pages** branch (published site), intake
`pmlint` exits successfully without checking. Use `--force` to run intake
anyway, or use **posts** mode for FAQ-style `_posts` edits:

```bash
# On the branch that holds _posts/ (often gh-pages)
pmlint posts --check
pmlint posts --check --changed          # only posts changed vs HEAD^
pmlint posts --check --changed --base origin/gh-pages
```

**PR CI:** volume repositories can copy
[`.github/workflows/pmlint-volume-example.yml`](.github/workflows/pmlint-volume-example.yml)
(intake) and/or
[`.github/workflows/pmlint-posts-volume-example.yml`](.github/workflows/pmlint-posts-volume-example.yml)
(`_posts` corrections). Papersite runs `tests/test_pmlint.sh` and
`tests/test_check_posts.sh` via `.github/workflows/test-pmlint.yml`.

**Fleet rollout (CIP-000A):** classify which volume clones already have a
workflow (read-only):

```bash
bin/pmfleet inventory --campaign pmlint-posts-ci --clones-dir ~/mlresearch
bin/pmfleet plan --campaign pmlint-posts-ci --clones-dir ~/mlresearch
bin/pmfleet status --campaign pmlint-posts-ci --clones-dir ~/mlresearch
bin/pmfleet apply --campaign pmlint-posts-ci --clones-dir ~/mlresearch \
  --open-prs --limit 5
```

Campaign YAML and schema: [`fleet/README.md`](fleet/README.md).
`apply` requires `--open-prs` and opens branch+PR only (no force-push).

### Lint published posts

After publication, citation fixes go in `_posts/*.md` (not BibTeX). Validate with:

```bash
cd ~/mlresearch/v304   # checkout with _posts present
pmlint posts --check
```

Checks: YAML/frontmatter fences, required keys (`layout`, `title`, `author`,
`id`, `pdf`), `extras` shape, display vs `bibtex_author` / `tex_title`
consistency (with LaTeX/Unicode folding), software URL hygiene (placeholders
allowed), and non-printable characters. Single-name authors (mononyms) belong
in `family` with empty/absent `given`, and in `bibtex_author` as `Name,,` —
see the [PMLR FAQ](https://proceedings.mlr.press/faq.html) correction section.
`check_posts` warns on inverted `given`-only mononyms.

### Classic workflow steps

The standard workflow for publishing a PMLR volume:

1. **Pre-publication check**: `pmlint --check` (or `check_volume.sh`)
2. **BibTeX cleaning**: `pmlint --fix` and/or `tidy_bibtex.rb`
3. **Volume creation**: Use `create_volume.rb` to generate Jekyll posts and organise assets
4. **Deployment**: Use `deploy_volume.sh` for the two-branch separation strategy

### Step 1 — Pre-publication Check

Run this first to catch common submission errors before processing:

```bash
cd ~/mlresearch/v304
pmlint --check
# equivalent lower-level tool:
../papersite/bin/check_volume.sh          # or: check_volume.sh v304
```

The checker validates:

| Check | What it catches |
|---|---|
| `@Proceedings` entry | Missing required fields (`name`, `volume`, …); `volume` not in braces; if `published` is present it must be `YYYY-MM-DD` (missing `published` is OK at submission — set when publishing); `published = {}` is an error |
| PDF locations | PDFs in subdirectories (e.g. `pdfs/`) instead of the repository root; permission/consent PDF directories (e.g. `v304permissions/`) are ignored |
| Supplementary locations | Supp files in subdirectories (e.g. `supplementary_material/`) instead of root |
| BibTeX key / PDF match | Keys without a matching PDF; orphaned PDFs with no BibTeX entry; hyphenated keys (e.g. `hernandez-garcia25`) are fully supported |
| Author name formatting | Missing comma separator (`YanjunXu` → `Xu, Yanjun`); lowercase surname; reversed `Given, Surname` order |
| Double backslashes | `\\textit`, `\\Delta`, etc. that should be single backslash |
| Escaped characters | `\$`, `\{`, `\}`, `\_` in abstracts/titles that should be unescaped |
| Double-braced pages | `pages = {{4-24}}` instead of `{4-24}` — renders page numbers with literal braces on the site |
| Non-ASCII BibTeX keys | Keys like `miñoza26` that will fail during processing |
| PDF extraction ligatures | Unicode `ﬀ`/`ﬁ`/`ﬂ`/`ﬃ`/`ﬄ` (U+FB00–FB06) from PDF text extraction — replace with ASCII `ff`/`fi`/`fl`/`ffi`/`ffl` |
| PDF line-wrap hyphens | ASCII `knowl- edge` / `state- of-the-art` from PDF line breaks — fix with `tidy_bibtex --fix-wrap-hyphens` or `pmlint --fix` |
| Over-escaped `\textbackslash` | `\textbackslash{}log` instead of `\log` — fix with `tidy_bibtex --fix-textbackslash` or `pmlint --fix` |

The script exits `0` if all checks pass, `1` if any errors are found.

### Step 2 — BibTeX Cleaning

```bash
ruby lib/tidy_bibtex.rb proceedings.bib proceedings.bib \
  --fix-percent --fix-wrap-hyphens --fix-textbackslash
```

### Step 3 — Volume Creation

```bash
ruby lib/create_volume.rb -v 304 -b proceedings.bib

# If PDFs are in a separate branch, skip PDF existence checks
ruby lib/create_volume.rb -v 304 -b proceedings.bib --skip-pdf-check
```

### Step 4 — Deployment

```bash
# Non-interactive (for scripted/automated use):
cd ~/mlresearch/v304
SKIP_CONFIRM=1 bash ../papersite/bin/deploy_volume.sh 304

# Interactive (prompts "Continue? (yes/no)" — default when run manually):
cd ~/mlresearch/v304
bash ../papersite/bin/deploy_volume.sh 304
```

The script must be run **from the volume directory**, not from `papersite/`. It requires `_posts/`, `_config.yml`, and `assets/` to exist (generated by `create_volume.rb`) and an `origin` remote pointing to `github.com:mlresearch/vNNN`.

This creates:
- **main branch**: Assets (PDFs, supplementary files) and `README.md`
- **gh-pages branch**: Jekyll site files served by GitHub Pages

Both branches are pushed to GitHub. The published site will be available at `https://mlresearch.github.io/vNNN/` once GitHub Pages rebuilds (usually within a minute).


### Known BibTeX Edge Cases

Issues that have occurred in real submissions and are worth fixing before running the pipeline:

**Empty or malformed publication date**
`published` may be omitted at submission (set when the volume goes live).
If present, it must be `published = {YYYY-MM-DD}`. Empty `published = {}` is an error.

**LaTeX formatting commands in abstracts**
Commands such as `{\color{blue}{...}}` or `\textcolor` in abstracts cause BibTeX parse failures due to unbalanced braces. Strip all LaTeX colour/formatting commands from abstracts before submission — they are not rendered in the proceedings HTML anyway.

**Unicode characters in abstracts and titles**
Characters such as `É`, `–`, `'` (left single quote, U+2018) in abstracts or titles are replaced by their LaTeX equivalents during processing via `unicode_replacements.yml`. If `create_volume.rb` errors with "No substitution found for Unicode character X", add an entry to `lib/unicode_replacements.yml`:

```yaml
X:
  replacement: "\\'{E}"   # LaTeX equivalent
  name: LATIN CAPITAL LETTER E WITH ACUTE
```

**Hyphenated BibTeX keys**
Keys such as `hernandez-garcia25` are valid and fully supported by the checker and pipeline. They do not need to be renamed.

**Non-ASCII BibTeX keys**
Keys such as `miñoza26` are dropped silently by the BibTeX parser if they reach generation. `check_volume.rb` and `create_volume.rb` both refuse them and list every offending key. Rename the citekey to ASCII in the source `.bib` (do not rely on unicode tidying, which would change the identifier).

**Permission/consent PDF directories**
Directories named `*permissions*` or `*permission*` (e.g. `v330permissions/`) are excluded from the PDF-location check. They are also removed during deployment and do not appear in either published branch.

## Testing

The repository has two test suites covering different components.

### BibTeX Cleaner — `test/`

Ruby `Test::Unit` tests for `tidy_bibtex.rb`. Covers auto-detection, issue
detection and fixing, command-line options, and edge cases.

```bash
ruby test/run_tests.rb          # run all BibTeX cleaner tests
ruby test/test_bibtex_cleaner.rb  # run a single file
```

See [`test/README.md`](test/README.md) for full details and conventions.

### Volume Checker — `tests/`

Bash regression tests for `check_volume.rb`, using real bib files extracted
from git history as fixtures for known-bad submissions, plus synthetic
fixtures for file-location checks.

```bash
cd ~/mlresearch/papersite
bash tests/test_check_volume.sh           # check_volume.rb regression tests
bash tests/test_create_volume_keys.sh     # create_volume.rb refuses non-ASCII keys
```

**Fixtures** (`tests/fixtures/`):

| Fixture | Source | Tests |
|---|---|---|
| `v304_original/` | `git show 59fd75f:proceedings.bib` | Author errors, double backslashes, escaped chars, `volume` not in braces |
| `v328_original/` | `git show 0545422:CPAL26.bib` | Non-ASCII BibTeX keys |
| `pdfs_in_subdir/` | Synthetic | PDFs in `pdfs/` subdirectory |
| `supps_in_subdir/` | Synthetic | Supplementary files in `supplementary_material/` |
| `clean_volume/` | Synthetic | All checks pass; zero-exit regression |

See [`tests/README.md`](tests/README.md) for fixture details and guidance on adding new tests.

## Ruby Code

The Ruby code is used for creating Jekyll sites for hosting PMLR on GitHub Pages. The main code is found in `lib/mlresearch.rb`.

### Requirements

The Ruby scripts depend on the following packages:

- ActiveRecord
- bibtex-ruby
- facets
- pandoc-ruby

You can install these packages using:

```bash
gem install bibtex-ruby facets pandoc-ruby activerecord
```

Alternatively, you can use the provided `Gemfile` with:

```bash
bundle install
```

### Usage

For detailed usage instructions, refer to the `lib/README.md` file.

## Contributing

To suggest fixes or improvements, please make a pull request containing the changes requested and a justification for the changes.

For details on how to publish in PMLR, please check [PMLR FAQ](https://proceedings.mlr.press/faq.html).

For details on what is required to submit a proceedings, please check [PMLR Specification](https://proceedings.mlr.press/spec.html).

