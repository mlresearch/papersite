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

# --- pmlint posts --fix repairs wrap hyphens / textbackslash then passes ---
TMP=$(mktemp -d)
cp -R "$FIXTURES/posts_wrap_hyphens" "$TMP/v991"
set +e
(cd "$TMP/v991" && "$PMLINT" posts --check) >/tmp/pmlint_posts_wrap_check.txt 2>&1
rc=$?
set -e
assert_eq "pmlint posts --check wrap fixture fails" "$rc" "1"
set +e
(cd "$TMP/v991" && "$PMLINT" posts --fix) >/tmp/pmlint_posts_wrap_fix.txt 2>&1
rc=$?
set -e
assert_eq "pmlint posts --fix wrap fixture exits 0" "$rc" "0"
if grep -q 'pmlint posts: PASSED' /tmp/pmlint_posts_wrap_fix.txt \
  && grep -q 'tidy_posts' /tmp/pmlint_posts_wrap_fix.txt; then
  PASS=$((PASS + 1))
  if [[ -n "$VERBOSE" ]]; then echo "  ✓ PASS: posts --fix wrap repaired"; fi
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL [posts --fix wrap did not pass]")
  echo "  ✗ FAIL: posts --fix wrap did not pass"
  if [[ -n "$VERBOSE" ]]; then cat /tmp/pmlint_posts_wrap_fix.txt; fi
fi
if ! grep -qE '[A-Za-z]- [a-z]' "$TMP/v991/_posts/"*.md; then
  PASS=$((PASS + 1))
  if [[ -n "$VERBOSE" ]]; then echo "  ✓ PASS: wrap hyphens removed from post file"; fi
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL [wrap hyphens still in post after --fix]")
  echo "  ✗ FAIL: wrap hyphens still in post after --fix"
fi
rm -rf "$TMP"

TMP=$(mktemp -d)
cp -R "$FIXTURES/posts_textbackslash" "$TMP/v992"
set +e
(cd "$TMP/v992" && "$PMLINT" posts --fix) >/tmp/pmlint_posts_tbs_fix.txt 2>&1
rc=$?
set -e
assert_eq "pmlint posts --fix textbackslash exits 0" "$rc" "0"
if ! grep -q 'textbackslash' "$TMP/v992/_posts/"*.md; then
  PASS=$((PASS + 1))
  if [[ -n "$VERBOSE" ]]; then echo "  ✓ PASS: textbackslash removed from post file"; fi
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL [textbackslash still in post after --fix]")
  echo "  ✗ FAIL: textbackslash still in post after --fix"
fi
rm -rf "$TMP"

# --- cross-line YAML wrap (ap-\n  proximations) fixed by tidy_posts ---
TMP=$(mktemp -d)
mkdir -p "$TMP/vol/_posts"
cp "$FIXTURES/posts_clean/_posts/2026-04-06-doe26a.md" "$TMP/vol/_posts/cross.md"
# Insert a cross-line wrap into the abstract
ruby -e '
path = ARGV[0]
t = File.read(path)
t.sub!(/abstract: This is a valid fixture post for pmlint posts checks\./,
       "abstract: This is a valid fixture post for pmlint posts checks with ap-\n  proximations remaining.")
File.write(path, t)
' "$TMP/vol/_posts/cross.md"
set +e
ruby "$ROOT/lib/check_posts.rb" -d "$TMP/vol" >/tmp/cross_before.txt 2>&1
rc=$?
set -e
assert_eq "cross-line wrap fails check before fix" "$rc" "1"
set +e
(cd "$TMP/vol" && "$PMLINT" posts --fix) >/tmp/cross_fix.txt 2>&1
rc=$?
set -e
assert_eq "pmlint posts --fix cross-line exits 0" "$rc" "0"
if grep -q 'approximations' "$TMP/vol/_posts/cross.md" && ! grep -qE 'ap-$' "$TMP/vol/_posts/cross.md"; then
  PASS=$((PASS + 1))
  if [[ -n "$VERBOSE" ]]; then echo "  ✓ PASS: cross-line wrap joined"; fi
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL [cross-line wrap not joined]")
  echo "  ✗ FAIL: cross-line wrap not joined"
  if [[ -n "$VERBOSE" ]]; then cat "$TMP/vol/_posts/cross.md"; fi
fi
rm -rf "$TMP"

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
