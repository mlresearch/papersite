#!/bin/bash

# =============================================================================
# test_create_volume_keys.sh — create_volume.rb must fail on non-ASCII keys
# =============================================================================
#
# papersite#2: invalid citekeys were dropped silently during generation.
# create_volume.rb must refuse the input and name every bad key *before*
# unicode tidying (which would rewrite the identifiers).
#
# Usage:
#   bash tests/test_create_volume_keys.sh
#   bash tests/test_create_volume_keys.sh --verbose

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CREATE="$SCRIPT_DIR/../lib/create_volume.rb"
FIXTURES="$SCRIPT_DIR/fixtures"
VERBOSE="${1:-}"

PASS=0
FAIL=0
ERRORS=()

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

assert_exit_fail() {
  local test_name="$1" status="$2"
  if [[ "$status" -ne 0 ]]; then
    PASS=$((PASS + 1))
    [[ -n "$VERBOSE" ]] && echo "  ✓ PASS: $test_name (correctly exits non-zero)"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("FAIL [$test_name]: expected non-zero exit but got 0")
    echo "  ✗ FAIL: $test_name (expected failure exit)"
  fi
}

assert_exit_pass_check() {
  local test_name="$1" status="$2"
  if [[ "$status" -eq 0 ]]; then
    PASS=$((PASS + 1))
    [[ -n "$VERBOSE" ]] && echo "  ✓ PASS: $test_name"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("FAIL [$test_name]: expected zero exit but got ${status}")
    echo "  ✗ FAIL: $test_name"
  fi
}

echo "============================================================"
echo "  create_volume.rb invalid-key tests"
echo "============================================================"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo
echo "── v328 original — non-ASCII BibTeX keys"

set +e
OUT=$(cd "$TMP" && ruby "$CREATE" -v 328 -b "$FIXTURES/v328_original/CPAL26.bib" --skip-pdf-check --quiet 2>&1)
STATUS=$?
set -e

assert_exit_fail "v328 create_volume exits non-zero" "$STATUS"
assert_error "v328 names miñoza26" "$OUT" "Non-ASCII character in key: 'miñoza26'"
assert_error "v328 names schrödter26" "$OUT" "Non-ASCII character in key: 'schrödter26'"

if [[ -d "$TMP/_posts" ]]; then
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL [v328 no posts]: create_volume wrote _posts despite invalid keys")
  echo "  ✗ FAIL: v328 must not write _posts"
else
  PASS=$((PASS + 1))
  [[ -n "$VERBOSE" ]] && echo "  ✓ PASS: v328 did not write _posts"
fi

echo
echo "── clean_volume — ASCII keys pass the key check"

CLEAN_BIB="$FIXTURES/clean_volume/proceedings.bib"
KEYS_RB="$SCRIPT_DIR/../lib/bibtex_keys.rb"
set +e
ruby -e "
  require '$KEYS_RB'
  BibTeXKeys.assert_valid_keys!(File.read('$CLEAN_BIB', encoding: 'UTF-8'))
"
STATUS=$?
set -e
assert_exit_pass_check "clean_volume keys are ASCII" "$STATUS"

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
