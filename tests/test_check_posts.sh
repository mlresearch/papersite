#!/usr/bin/env bash
# =============================================================================
# test_check_posts.sh — Smoke tests for lib/check_posts.rb / pmlint posts
# =============================================================================
#
# Usage (from papersite root):
#   bash tests/test_check_posts.sh
#   bash tests/test_check_posts.sh --verbose
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PMLINT="$ROOT/bin/pmlint"
CHECK="$ROOT/lib/check_posts.rb"
FIXTURES="$SCRIPT_DIR/fixtures"
VERBOSE="${1:-}"
export PMLINT_SKIP_UPDATE=1
export PAPERSITE_ROOT="$ROOT"

PASS=0
FAIL=0
ERRORS=()

assert_eq() {
  local name="$1" got="$2" want="$3"
  if [[ "$got" == "$want" ]]; then
    PASS=$((PASS + 1))
    if [[ -n "$VERBOSE" ]]; then echo "  ✓ PASS: $name"; fi
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("FAIL [$name]: got='$got' want='$want'")
    echo "  ✗ FAIL: $name (got='$got' want='$want')"
  fi
}

checksum_tree() {
  local dir="$1"
  (cd "$dir" && find . -type f | sort | while IFS= read -r f; do cksum "$f"; done)
}
echo "=== check_posts / pmlint posts smoke tests ==="

# --- clean fixture passes; tree untouched ---
TMP=$(mktemp -d)
cp -R "$FIXTURES/posts_clean" "$TMP/vol"
BEFORE=$(checksum_tree "$TMP/vol")
set +e
ruby "$CHECK" -d "$TMP/vol" >/tmp/check_posts_clean.txt 2>&1
rc=$?
set -e
assert_eq "check_posts clean exit" "$rc" "0"
AFTER=$(checksum_tree "$TMP/vol")
assert_eq "check_posts does not touch tree" "$BEFORE" "$AFTER"
rm -rf "$TMP"

# --- pmlint posts --check on clean ---
TMP=$(mktemp -d)
cp -R "$FIXTURES/posts_clean" "$TMP/v999"
set +e
(cd "$TMP/v999" && "$PMLINT" posts --check) >/tmp/pmlint_posts_clean.txt 2>&1
rc=$?
set -e
assert_eq "pmlint posts --check clean exit" "$rc" "0"
if grep -q "pmlint posts: PASSED" /tmp/pmlint_posts_clean.txt; then
  PASS=$((PASS + 1))
  if [[ -n "$VERBOSE" ]]; then echo "  ✓ PASS: posts PASSED banner"; fi
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL [missing posts PASSED banner]")
  echo "  ✗ FAIL: missing posts PASSED banner"
  if [[ -n "$VERBOSE" ]]; then cat /tmp/pmlint_posts_clean.txt; fi
fi
rm -rf "$TMP"

# --- soak-learned pass fixtures (LaTeX fold, placeholders, legacy URLs, mononym) ---
for fix in posts_title_fold posts_software_placeholder posts_mononym_ok; do
  TMP=$(mktemp -d)
  cp -R "$FIXTURES/$fix" "$TMP/vol"
  set +e
  ruby "$CHECK" -d "$TMP/vol" >/tmp/check_posts_pass.txt 2>&1
  rc=$?
  set -e
  assert_eq "check_posts $fix exit" "$rc" "0"
  rm -rf "$TMP"
done

# --- inverted mononym warns but does not fail (warn-first policy) ---
TMP=$(mktemp -d)
cp -R "$FIXTURES/posts_mononym_inverted" "$TMP/vol"
set +e
ruby "$CHECK" -d "$TMP/vol" >/tmp/check_posts_mononym_warn.txt 2>&1
rc=$?
set -e
assert_eq "check_posts posts_mononym_inverted exit" "$rc" "0"
if grep -qi "mononym should use family" /tmp/check_posts_mononym_warn.txt; then
  PASS=$((PASS + 1))
  if [[ -n "$VERBOSE" ]]; then echo "  ✓ PASS: inverted mononym warns"; fi
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL [posts_mononym_inverted missing mononym warning]")
  echo "  ✗ FAIL: posts_mononym_inverted missing mononym warning"
  if [[ -n "$VERBOSE" ]]; then cat /tmp/check_posts_mononym_warn.txt; fi
fi
rm -rf "$TMP"

# --- failure classes ---
for pair in \
  "posts_bad_yaml:invalid YAML" \
  "posts_bad_extras:extras must be a list" \
  "posts_author_mismatch:author count" \
  "posts_author_swap:author / bibtex_author mismatch" \
  "posts_missing_pdf:missing required key: pdf" \
  "posts_control_char:non-printable" \
  "posts_title_mismatch:title and tex_title diverge" \
  "posts_wrap_hyphens:PDF wrap hyphen" \
  "posts_textbackslash:textbackslash"
do
  fix="${pair%%:*}"
  needle="${pair#*:}"
  TMP=$(mktemp -d)
  cp -R "$FIXTURES/$fix" "$TMP/vol"
  set +e
  ruby "$CHECK" -d "$TMP/vol" >/tmp/check_posts_bad.txt 2>&1
  rc=$?
  set -e
  assert_eq "check_posts $fix exit" "$rc" "1"
  if grep -qi "$needle" /tmp/check_posts_bad.txt; then
    PASS=$((PASS + 1))
    if [[ -n "$VERBOSE" ]]; then echo "  ✓ PASS: $fix reports $needle"; fi
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("FAIL [$fix missing message: $needle]")
    echo "  ✗ FAIL: $fix missing message: $needle"
    if [[ -n "$VERBOSE" ]]; then cat /tmp/check_posts_bad.txt; fi
  fi
  rm -rf "$TMP"
done

# --- intake still skips published (regression) ---
TMP=$(mktemp -d)
cp -R "$FIXTURES/clean_volume" "$TMP/v996"
(
  cd "$TMP/v996"
  # Pin initial branch: CI runners often still default git init to "master".
  git init -q -b main
  git config user.email "test@example.com"
  git config user.name "Test"
  git add -A
  git commit -qm "main content"
  git checkout -qb gh-pages
  echo "title: test" > _config.yml
  git add _config.yml
  git commit -qm "site"
  git checkout -q main
)
set +e
(cd "$TMP/v996" && "$PMLINT" --check) >/tmp/pmlint_intake_skip.txt 2>&1
rc=$?
set -e
assert_eq "intake still skips published" "$rc" "0"
rm -rf "$TMP"

echo
echo "Passed: $PASS  Failed: $FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  printf '%s\n' "${ERRORS[@]}"
  exit 1
fi
echo "All check_posts smoke tests passed."
exit 0
