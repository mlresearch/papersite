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
#   fixtures/pdfs_in_subdir/  — Synthetic: PDFs in pdfs/ not root
#   fixtures/supps_in_subdir/ — Synthetic: supps in supplementary_material/
#   fixtures/clean_volume/    — Synthetic: all checks should pass
#
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
    [[ -n "$VERBOSE" ]] && echo "  ✓ PASS: $test_name"
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
    [[ -n "$VERBOSE" ]] && echo "  ✓ PASS: $test_name"
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
    [[ -n "$VERBOSE" ]] && echo "  ✓ PASS: $test_name (correctly exits non-zero)"
  fi
}

assert_exit_pass() {
  local test_name="$1" dir="$2" vol="$3"
  if ruby "$CHECKER" -v "$vol" -d "$dir" > /dev/null 2>&1; then
    PASS=$((PASS + 1))
    [[ -n "$VERBOSE" ]] && echo "  ✓ PASS: $test_name (correctly exits zero)"
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
assert_no_error "clean: no missing PDF"          "$OUT" "Missing PDF for key"
assert_no_error "clean: no PDF subdir error"     "$OUT" "in subdirectory"
assert_no_error "clean: no non-ASCII key"        "$OUT" "Non-ASCII character in key"
assert_exit_pass "clean exits zero"              "$FIXTURES/clean_volume" 999

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
