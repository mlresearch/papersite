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

The standard workflow for publishing a PMLR volume:

1. **Pre-publication check**: Use `check_volume.sh` to validate the volume directory before touching anything
2. **BibTeX cleaning**: Use `tidy_bibtex.rb` to fix common formatting issues
3. **Volume creation**: Use `create_volume.rb` to generate Jekyll posts and organise assets
4. **Deployment**: Use `deploy_volume.sh` for the two-branch separation strategy

### Step 1 — Pre-publication Check

Run this first to catch common submission errors before processing:

```bash
cd ~/mlresearch/v304
../papersite/bin/check_volume.sh 304
```

The checker validates:

| Check | What it catches |
|---|---|
| `@Proceedings` entry | Missing required fields (`published`, `name`, `volume`, …); `volume` not in braces; date not in `YYYY-MM-DD` format |
| PDF locations | PDFs in subdirectories (e.g. `pdfs/`) instead of the repository root |
| Supplementary locations | Supp files in subdirectories (e.g. `supplementary_material/`) instead of root |
| BibTeX key / PDF match | Keys without a matching PDF; orphaned PDFs with no BibTeX entry |
| Author name formatting | Missing comma separator (`YanjunXu` → `Xu, Yanjun`); lowercase surname; reversed `Given, Surname` order |
| Double backslashes | `\\textit`, `\\Delta`, etc. that should be single backslash |
| Escaped characters | `\$`, `\{`, `\}`, `\_` in abstracts/titles that should be unescaped |
| Non-ASCII BibTeX keys | Keys like `miñoza26` that will fail during processing |

The script exits `0` if all checks pass, `1` if any errors are found.

### Step 2 — BibTeX Cleaning

```bash
ruby lib/tidy_bibtex.rb proceedings.bib proceedings.bib --fix-percent
```

### Step 3 — Volume Creation

```bash
ruby lib/create_volume.rb -v 304 -b proceedings.bib

# If PDFs are in a separate branch, skip PDF existence checks
ruby lib/create_volume.rb -v 304 -b proceedings.bib --skip-pdf-check
```

### Step 4 — Deployment

```bash
echo "yes" | bash bin/deploy_volume.sh 304
```

This creates:
- **main branch**: Assets (PDFs, supplementary files) and `README.md`
- **gh-pages branch**: Jekyll site files served by GitHub Pages


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
bash tests/test_check_volume.sh           # run all regression tests
bash tests/test_check_volume.sh --verbose # show every individual assertion
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

