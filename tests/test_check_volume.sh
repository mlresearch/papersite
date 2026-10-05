#!/bin/bash

# =============================================================================
# test_check_volume.sh — Regression tests for check_volume.rb
# =============================================================================
#
# Each test runs check_volume.rb against a fixture directory and asserts that
# specific error strings appear (or don't appear) in the output.
#
# Fixtures:
#   fixtures/v304_original/   — Real bib from v304 PR before fixes
#                               (author errors, double backslashes, escaped chars)
#   fixtures/v328_original/   — Real bib from v328 PR before fixes
#                               (non-ASCII BibTeX keys)
#   fixtures/v283_original/   — Real brindise25a entry from v283 before fixes
#                               (mojibake C1 controls U+0080/U+009D in title)
#   fixtures/v316_original/   — Real lucassen25 entry from v316 before fixes
#                               (raw U+0002 STX PDF line-break artifacts)
#   fixtures/pdf_ligatures/   — Synthetic: Unicode ﬁ/ﬂ/ﬃ from PDF extraction
#   fixtures/pdf_wrap_hyphens/— Synthetic: ASCII "knowl- edge" PDF line-wrap hyphens
#   fixtures/pdfs_in_subdir/  — Synthetic: PDFs in pdfs/ not root
#   fixtures/supps_in_subdir/ — Synthetic: supps in supplementary_material/
#   fixtures/clean_volume/    — Synthetic: all checks should pass
#                               (includes legitimate UTF-8 punctuation)#
# Usage:
#   cd ~/mlresearch/papersite
#   bash tests/test_check_volume.sh
#   bash tests/test_check_volume.sh --verbose

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKER="$SCRIPT_DIR/../lib/check_volume.rb"
FIXTURES="$SCRIPT_DIR/fixtures"
VERBOSE="${1:-}"

# =============================================================================
# Mini test framework
# =============================================================================

PASS=0
FAIL=0
ERRORS=()

run_checker() {
  local vol="$1" dir="$2"
  ruby "$CHECKER" -v "$vol" -d "$dir" 2>&1 || true
}

assert_error() {
  local test_name="$1" output="$2" pattern="$3"
  if echo "$output" | grep -qF "$pattern"; then
    PASS=$((PASS + 1))
    if [[ -n "$VERBOSE" ]]; then echo "  ✓ PASS: $test_name"; fi
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("FAIL [$test_name]: expected to find '${pattern}'")
    echo "  ✗ FAIL: $test_name"
    echo "         expected: $pattern"
  fi
}

assert_no_error() {
  local test_name="$1" output="$2" pattern="$3"
  if echo "$output" | grep -qF "$pattern"; then
    FAIL=$((FAIL + 1))
    ERRORS+=("FAIL [$test_name]: did NOT expect to find '${pattern}'")
    echo "  ✗ FAIL: $test_name"
    echo "         unexpected: $pattern"
  else
    PASS=$((PASS + 1))
    if [[ -n "$VERBOSE" ]]; then echo "  ✓ PASS: $test_name"; fi
  fi
}

assert_exit_fail() {
  local test_name="$1" dir="$2" vol="$3"
  if ruby "$CHECKER" -v "$vol" -d "$dir" > /dev/null 2>&1; then
    FAIL=$((FAIL + 1))
    ERRORS+=("FAIL [$test_name]: expected non-zero exit but got 0")
    echo "  ✗ FAIL: $test_name (expected failure exit)"
  else
    PASS=$((PASS + 1))
    if [[ -n "$VERBOSE" ]]; then echo "  ✓ PASS: $test_name (correctly exits non-zero)"; fi
  fi
}

assert_exit_pass() {
  local test_name="$1" dir="$2" vol="$3"
  if ruby "$CHECKER" -v "$vol" -d "$dir" > /dev/null 2>&1; then
    PASS=$((PASS + 1))
    if [[ -n "$VERBOSE" ]]; then echo "  ✓ PASS: $test_name (correctly exits zero)"; fi
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("FAIL [$test_name]: expected zero exit but got non-zero")
    echo "  ✗ FAIL: $test_name (expected clean pass)"
  fi
}

section() { echo; echo "── $1"; }

# =============================================================================
# Test suite
# =============================================================================

echo "============================================================"
echo "  check_volume.rb regression tests"
echo "============================================================"

# ---------------------------------------------------------------------------
section "v304 original — author name errors"
# ---------------------------------------------------------------------------
OUT=$(run_checker 304 "$FIXTURES/v304_original")

assert_error  "v304 no-comma YanjunXu"   "$OUT" "No comma in name: 'YanjunXu'"
assert_error  "v304 no-comma yimingqiao" "$OUT" "No comma in name: 'yimingqiao'"
assert_error  "v304 no-comma Ziboxu"     "$OUT" "No comma in name: 'Ziboxu'"
assert_error  "v304 no-comma ZeRong"     "$OUT" "No comma in name: 'ZeRong'"
assert_error  "v304 lowercase hu"        "$OUT" "Lowercase surname: 'hu, Jianhua'"
assert_error  "v304 lowercase shen"      "$OUT" "Lowercase surname: 'shen, yelong'"
assert_exit_fail "v304 exits non-zero"   "$FIXTURES/v304_original" 304

# ---------------------------------------------------------------------------
section "v304 original — double backslashes"
# ---------------------------------------------------------------------------
assert_error "v304 double-backslash wu25"    "$OUT" "[wu25]"
assert_error "v304 double-backslash jiang25" "$OUT" "[jiang25]"
assert_error "v304 double-backslash li25"    "$OUT" "[li25]"

# ---------------------------------------------------------------------------
section "v304 original — escaped chars in abstracts/titles"
# ---------------------------------------------------------------------------
assert_error "v304 escaped-dollar jiang25"  "$OUT" "should be unescaped"
assert_error "v304 escaped-brace wu25"      "$OUT" "should be unescaped"

# ---------------------------------------------------------------------------
section "v304 original — proceedings entry"
# ---------------------------------------------------------------------------
assert_error  "v304 volume not in braces" "$OUT" "volume value not wrapped in braces"
assert_no_error "v304 published present"  "$OUT" "Missing required field: published"

# ---------------------------------------------------------------------------
section "missing published — optional at submission"
# ---------------------------------------------------------------------------
TMP_PUB=$(mktemp -d)
cp -R "$FIXTURES/clean_volume/." "$TMP_PUB/"
# Strip published line from proceedings.bib
sed -i.bak '/published/d' "$TMP_PUB/proceedings.bib"
rm -f "$TMP_PUB/proceedings.bib.bak"
OUT=$(run_checker 999 "$TMP_PUB")
assert_no_error "no-published: not a missing-field error" "$OUT" "Missing required field: published"
assert_error    "no-published: notes optional" "$OUT" "published not set"
assert_exit_pass "no-published exits zero" "$TMP_PUB" 999
rm -rf "$TMP_PUB"

# ---------------------------------------------------------------------------
section "empty published = {} — still an error"
# ---------------------------------------------------------------------------
TMP_EMPTY=$(mktemp -d)
cp -R "$FIXTURES/clean_volume/." "$TMP_EMPTY/"
sed -i.bak 's/published.*=.*/published = {},/' "$TMP_EMPTY/proceedings.bib"
rm -f "$TMP_EMPTY/proceedings.bib.bak"
OUT=$(run_checker 999 "$TMP_EMPTY")
assert_error "empty-published: bad format" "$OUT" "published field present but not in YYYY-MM-DD format"
assert_exit_fail "empty-published exits non-zero" "$TMP_EMPTY" 999
rm -rf "$TMP_EMPTY"

# ---------------------------------------------------------------------------
section "v328 original — non-ASCII BibTeX keys"
# ---------------------------------------------------------------------------
OUT=$(run_checker 328 "$FIXTURES/v328_original")

assert_error "v328 non-ASCII miñoza26"   "$OUT" "Non-ASCII character in key"
assert_error "v328 non-ASCII schrödter" "$OUT" "Non-ASCII character in key"
assert_exit_fail "v328 exits non-zero"  "$FIXTURES/v328_original" 328

# ---------------------------------------------------------------------------
section "pdfs_in_subdir — PDFs in wrong location"
# ---------------------------------------------------------------------------
OUT=$(run_checker 999 "$FIXTURES/pdfs_in_subdir")

assert_error    "pdfs-subdir: error for pdfs/"  "$OUT" "PDF(s) in subdirectory 'pdfs/'"
assert_no_error "pdfs-subdir: no false positives on supps" "$OUT" "supplementary_material"
assert_exit_fail "pdfs-subdir exits non-zero"   "$FIXTURES/pdfs_in_subdir" 999

# ---------------------------------------------------------------------------
section "supps_in_subdir — supplementary files in wrong location"
# ---------------------------------------------------------------------------
OUT=$(run_checker 999 "$FIXTURES/supps_in_subdir")

assert_error    "supps-subdir: error for supplementary_material/" "$OUT" "supplementary file(s) in subdirectory 'supplementary_material/'"
assert_no_error "supps-subdir: PDFs are fine"   "$OUT" "PDF(s) in subdirectory"
assert_exit_fail "supps-subdir exits non-zero"  "$FIXTURES/supps_in_subdir" 999

# ---------------------------------------------------------------------------
section "clean_volume — all checks should pass"
# ---------------------------------------------------------------------------
OUT=$(run_checker 999 "$FIXTURES/clean_volume")

assert_no_error "clean: no author errors"        "$OUT" "No comma in name"
assert_no_error "clean: no double backslash"     "$OUT" "] line "
assert_no_error "clean: no escaped chars"        "$OUT" "should be unescaped"
assert_no_error "clean: no double-braced pages"    "$OUT" "double braces"
assert_no_error "clean: no missing PDF"          "$OUT" "Missing PDF for key"
assert_no_error "clean: no PDF subdir error"     "$OUT" "in subdirectory"
assert_no_error "clean: no non-ASCII key"        "$OUT" "Non-ASCII character in key"
assert_no_error "clean: no non-printable chars"  "$OUT" "non-printable character U+"
assert_no_error "clean: no PDF ligatures"        "$OUT" "PDF ligature"
assert_no_error "clean: no PDF wrap hyphens"     "$OUT" "PDF wrap hyphen"
assert_exit_pass "clean exits zero"              "$FIXTURES/clean_volume" 999

# ---------------------------------------------------------------------------
section "pdf_ligatures — presentation-form ligatures from PDF extraction"
# ---------------------------------------------------------------------------
OUT=$(run_checker 888 "$FIXTURES/pdf_ligatures")

assert_error "pdf-ligatures: ffi (U+FB03)" "$OUT" "PDF ligature ﬃ (U+FB03)"
assert_error "pdf-ligatures: fi (U+FB01)"  "$OUT" "PDF ligature ﬁ (U+FB01)"
assert_error "pdf-ligatures: fl (U+FB02)"  "$OUT" "PDF ligature ﬂ (U+FB02)"
assert_error "pdf-ligatures: attributes to adams10a" "$OUT" "[adams10a]"
assert_no_error "pdf-ligatures: clean abstract not flagged" "$OUT" "[agovic10a]"
assert_exit_fail "pdf-ligatures exits non-zero" "$FIXTURES/pdf_ligatures" 888

# ---------------------------------------------------------------------------
section "pdf_wrap_hyphens — ASCII letter- space lowercase from PDF extraction"
# ---------------------------------------------------------------------------
OUT=$(run_checker 889 "$FIXTURES/pdf_wrap_hyphens")

assert_error "wrap-hyphens: knowl- edge" "$OUT" 'knowl- edge'
assert_error "wrap-hyphens: opti- mal"   "$OUT" 'opti- mal'
assert_error "wrap-hyphens: state- of-the-art" "$OUT" 'state- of-the-art'
assert_error "wrap-hyphens: attributes to adams10a" "$OUT" "[adams10a]"
assert_no_error "wrap-hyphens: clean abstract not flagged" "$OUT" "[agovic10a]"
assert_no_error "wrap-hyphens: en-dash abstract not flagged" "$OUT" "[brown10a]"
assert_exit_fail "wrap-hyphens exits non-zero" "$FIXTURES/pdf_wrap_hyphens" 889

# ---------------------------------------------------------------------------
section "v283 original — mojibake C1 controls in title (U+0080/U+009D)"
# ---------------------------------------------------------------------------
OUT=$(run_checker 283 "$FIXTURES/v283_original")

assert_error "v283 non-printable U+0080" "$OUT" "non-printable character U+0080"
assert_error "v283 non-printable U+009D" "$OUT" "non-printable character U+009D"
assert_error "v283 attributes to brindise25a" "$OUT" "[brindise25a]"
assert_exit_fail "v283 exits non-zero" "$FIXTURES/v283_original" 283

# ---------------------------------------------------------------------------
section "v316 original — raw U+0002 STX PDF line-break artifacts"
# ---------------------------------------------------------------------------
OUT=$(run_checker 316 "$FIXTURES/v316_original")

assert_error "v316 non-printable U+0002" "$OUT" "non-printable character U+0002"
assert_error "v316 attributes to lucassen25" "$OUT" "[lucassen25]"
assert_exit_fail "v316 exits non-zero" "$FIXTURES/v316_original" 316

# ---------------------------------------------------------------------------
section "math_braces — \\left\\{ and \\right\\} must not be flagged as escaped braces"
# ---------------------------------------------------------------------------
OUT=$(run_checker 888 "$FIXTURES/math_braces")

# \left\{ and \right\} are valid LaTeX math — must NOT trigger the escaped-brace check
assert_no_error "math-braces: \\left\\{ not flagged" "$OUT" "should be unescaped"
# Volume should pass cleanly
assert_exit_pass "math-braces exits zero"            "$FIXTURES/math_braces" 888

# v304 still catches genuine \emph\{...\} mistakes (regression guard)
OUT=$(run_checker 304 "$FIXTURES/v304_original")
assert_error "escaped-brace still caught after left/right fix" "$OUT" "should be unescaped"

# ---------------------------------------------------------------------------
section "double_braced_pages — pages = {{4-24}} must be flagged"
# ---------------------------------------------------------------------------
OUT=$(run_checker 888 "$FIXTURES/double_braced_pages")

assert_error "double-braced pages: jones26a" "$OUT" "[jones26a]"
assert_error "double-braced pages: smith26a" "$OUT" "[smith26a]"
assert_exit_fail "double-braced pages exits non-zero" "$FIXTURES/double_braced_pages" 888

# ---------------------------------------------------------------------------
section "proper_names_unprotected — CIP-000B bracing errors + unknown acronym warn"
# ---------------------------------------------------------------------------
OUT=$(run_checker 99002 "$FIXTURES/proper_names_unprotected")

assert_error "proper-names: unprotected Bayesian" "$OUT" 'unprotected "Bayesian"'
assert_error "proper-names: unprotected Markov"   "$OUT" 'unprotected "Markov"'
assert_error "proper-names: mentions FOOBAR warn"  "$OUT" 'unknown acronym "FOOBAR"'
assert_exit_fail "proper-names unprotected exits non-zero" "$FIXTURES/proper_names_unprotected" 99002

# ---------------------------------------------------------------------------
section "proper_names_ok — braced stems pass"
# ---------------------------------------------------------------------------
OUT=$(run_checker 99003 "$FIXTURES/proper_names_ok")

assert_no_error "proper-names-ok: no unprotected Bayesian" "$OUT" 'unprotected "Bayesian"'
assert_no_error "proper-names-ok: no unprotected Markov"   "$OUT" 'unprotected "Markov"'
assert_no_error "proper-names-ok: no unknown FOOBAR"       "$OUT" 'unknown acronym "FOOBAR"'
assert_exit_pass "proper-names-ok exits zero"              "$FIXTURES/proper_names_ok" 99003

# =============================================================================
# Summary
# =============================================================================

echo
echo "============================================================"
echo "  Results: ${PASS} passed, ${FAIL} failed"
echo "============================================================"

if [[ ${#ERRORS[@]} -gt 0 ]]; then
  echo
  for e in "${ERRORS[@]}"; do
    echo "  $e"
  done
  echo
  exit 1
else
  echo
  echo "  All tests passed."
  echo
  exit 0
fi
