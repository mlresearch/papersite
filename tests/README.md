# Regression Tests — Volume Checker

This directory contains regression tests for `lib/check_volume.rb`, the
pre-publication validation script for PMLR volumes.

## Running the Tests

```bash
# From the papersite root
bash tests/test_check_volume.sh

# Show every individual assertion (useful when adding new tests)
bash tests/test_check_volume.sh --verbose
```

Exit code `0` means all assertions passed; `1` means at least one failed.

## Test Structure

```
tests/
├── README.md                       # This file
├── test_check_volume.sh            # Test runner
└── fixtures/
    ├── v304_original/              # Real bib from v304 PR (known-bad)
    │   ├── proceedings.bib
    │   └── *.pdf                   # Dummy empty PDFs matching BibTeX keys
    ├── v328_original/              # Real bib from v328 PR (known-bad)
    │   ├── CPAL26.bib
    │   └── *.pdf
    ├── pdfs_in_subdir/             # Synthetic: PDFs in pdfs/ not root
    │   ├── proceedings.bib
    │   └── pdfs/*.pdf
    ├── supps_in_subdir/            # Synthetic: supps in supplementary_material/
    │   ├── proceedings.bib
    │   ├── *.pdf
    │   └── supplementary_material/*-supp.*
    └── clean_volume/               # Synthetic: all checks must pass
        ├── proceedings.bib
        ├── *.pdf
        └── *-supp.pdf
```

## Fixtures

### `v304_original/` — Real submission with multiple errors

Extracted from the v304 repository at commit `59fd75f` (the state of
`proceedings.bib` as submitted, before any corrections).

**Known errors this fixture must trigger:**

| Check | Expected error |
|---|---|
| Author names | `YanjunXu`, `yimingqiao`, `Ziboxu`, `ZeRong` — no comma |
| Author names | `hu, Jianhua`, `shen, yelong` — lowercase surname |
| Double backslashes | Entries `wu25`, `jiang25`, `li25`, and others |
| Escaped chars | `\$` and `\{` in abstracts of `jiang25`, `wu25` |
| Proceedings entry | `volume = 304` not in braces |

### `v328_original/` — Real submission with non-ASCII keys

Extracted from the v328 repository at commit `0545422`.

**Known errors this fixture must trigger:**

| Check | Expected error |
|---|---|
| BibTeX key characters | `miñoza26`, `schrödter26` contain non-ASCII |

### `pdfs_in_subdir/` — Synthetic file-location fixture

A minimal two-paper bib with both PDFs placed in a `pdfs/` subdirectory
instead of the repository root. Must trigger the PDF-in-subdirectory error
without triggering false positives on supplementary files.

### `supps_in_subdir/` — Synthetic file-location fixture

Same bib as above, but PDFs are correctly in the root while supplementary
files are in `supplementary_material/`. Must trigger the supplementary-in-
subdirectory error without triggering the PDF check.

### `clean_volume/` — Synthetic passing fixture

A well-formed two-paper bib with correct LaTeX (`$\delta$`, `\textit{...}`,
`$\mathbb{R}^{d}$`) and all PDFs and supplementary files in the root.
**Must produce zero errors and exit 0.**

## Adding New Tests

### Testing a new check in `check_volume.rb`

1. Add the new check method to `lib/check_volume.rb`.
2. If the new error is already triggered by an existing fixture, add a new
   `assert_error` call in `test_check_volume.sh` in the appropriate section.
3. If a new fixture is needed:
   - For BibTeX content issues: add a minimal `.bib` file to a new
     `fixtures/<name>/` directory along with the required dummy PDFs.
   - For file-location issues: create the directory structure with `touch`'d
     dummy files.
4. Add a corresponding `assert_no_error` assertion in the `clean_volume`
   section to guard against false positives.
5. Run `bash tests/test_check_volume.sh --verbose` to confirm all pass.

### Extracting a fixture from a real PR

When a new class of submission error is encountered, preserve it as a fixture
so the check is permanently regression-tested:

```bash
# Extract original bib from a volume repo's pre-fix commit
git -C ~/mlresearch/vNNN log --oneline   # find the merge commit hash
git -C ~/mlresearch/vNNN show <hash>:<bibfile.bib> \
  > tests/fixtures/vNNN_original/<bibfile.bib>

# Create matching dummy PDFs
python3 -c "
import re, pathlib
bib = open('tests/fixtures/vNNN_original/<bibfile.bib>').read()
for k in re.findall(r'@InProceedings\{(\w+),', bib, re.I):
    pathlib.Path(f'tests/fixtures/vNNN_original/{k}.pdf').touch()
"
```

## Test Framework

The test runner is plain bash with a small assertion library defined at the
top of `test_check_volume.sh`:

| Helper | Purpose |
|---|---|
| `assert_error TEST OUTPUT PATTERN` | Fails if `PATTERN` is absent from `OUTPUT` |
| `assert_no_error TEST OUTPUT PATTERN` | Fails if `PATTERN` is present in `OUTPUT` |
| `assert_exit_fail TEST DIR VOL` | Fails if `check_volume.rb` exits `0` |
| `assert_exit_pass TEST DIR VOL` | Fails if `check_volume.rb` exits non-zero |

**Choosing patterns carefully:** use strings that appear *only* in error
output, not in section headers or OK messages:

```bash
# Good — only present in error lines
assert_no_error "..." "$OUT" "should be unescaped"   # escaped chars
assert_no_error "..." "$OUT" "] line "               # double backslash

# Bad — also present in the section header / OK message
assert_no_error "..." "$OUT" "Double backslash"      # matches section header
assert_no_error "..." "$OUT" '\$'                    # matches OK summary line
```

## Relationship to `test/`

This directory (`tests/`) is distinct from `test/`:

| Directory | Framework | Covers |
|---|---|---|
| `test/` | Ruby `Test::Unit` | `tidy_bibtex.rb` (BibTeX cleaner) |
| `tests/` | Bash | `check_volume.rb` (pre-publication validator) |

Both suites are independent and can be run separately or together:

```bash
ruby test/run_tests.rb && bash tests/test_check_volume.sh
```
