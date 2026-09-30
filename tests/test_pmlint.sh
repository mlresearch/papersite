#!/usr/bin/env bash
# =============================================================================
# test_pmlint.sh — Smoke tests for bin/pmlint
# =============================================================================
#
# Usage (from papersite root):
#   bash tests/test_pmlint.sh
#   bash tests/test_pmlint.sh --verbose
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PMLINT="$ROOT/bin/pmlint"
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
  (cd "$dir" && find . -type f -print0 | sort -z | xargs -0 cksum)
}

echo "=== pmlint smoke tests ==="
echo "PAPERSITE_ROOT=$PAPERSITE_ROOT"

# --- help ---
if "$PMLINT" --help >/dev/null 2>&1; then
  PASS=$((PASS + 1))
  if [[ -n "$VERBOSE" ]]; then echo "  ✓ PASS: --help"; fi
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL [--help]")
  echo "  ✗ FAIL: --help"
fi

# --- dry-run tidy does not write ---
TMP=$(mktemp -d)
cp "$FIXTURES/clean_volume/proceedings.bib" "$TMP/proceedings.bib"
ruby "$ROOT/lib/tidy_bibtex.rb" --dry-run --strict --check-author-commas \
  "$TMP/proceedings.bib" >/dev/null
count=$(find "$TMP" -type f | wc -l | tr -d ' ')
assert_eq "tidy --dry-run file count unchanged" "$count" "1"
rm -rf "$TMP"

# --- check passes on clean fixture; tree untouched; id inferred from dir ---
TMP=$(mktemp -d)
cp -R "$FIXTURES/clean_volume" "$TMP/v999"
BEFORE=$(checksum_tree "$TMP/v999")
set +e
(cd "$TMP/v999" && "$PMLINT" --check) >/tmp/pmlint_clean_out.txt 2>&1
rc=$?
set -e
assert_eq "pmlint --check clean exit (inferred v999)" "$rc" "0"
if grep -q "volume=v999" /tmp/pmlint_clean_out.txt; then
  PASS=$((PASS + 1))
  if [[ -n "$VERBOSE" ]]; then echo "  ✓ PASS: inferred volume=v999"; fi
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL [did not infer volume=v999]")
  echo "  ✗ FAIL: did not infer volume=v999"
fi
AFTER=$(checksum_tree "$TMP/v999")
assert_eq "pmlint --check does not touch tree" "$BEFORE" "$AFTER"
rm -rf "$TMP"

# --- rerelease id r0 inferred from directory name ---
TMP=$(mktemp -d)
cp -R "$FIXTURES/clean_volume" "$TMP/r0"
set +e
(cd "$TMP/r0" && "$PMLINT" --check) >/tmp/pmlint_r0_out.txt 2>&1
rc=$?
set -e
assert_eq "pmlint --check r0 exit" "$rc" "0"
if grep -q "volume=r0" /tmp/pmlint_r0_out.txt; then
  PASS=$((PASS + 1))
  if [[ -n "$VERBOSE" ]]; then echo "  ✓ PASS: inferred volume=r0"; fi
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL [did not infer volume=r0]")
  echo "  ✗ FAIL: did not infer volume=r0"
  if [[ -n "$VERBOSE" ]]; then cat /tmp/pmlint_r0_out.txt; fi
fi
rm -rf "$TMP"

# --- check fails on pdfs-in-subdir fixture ---
TMP=$(mktemp -d)
cp -R "$FIXTURES/pdfs_in_subdir" "$TMP/v998"
set +e
(cd "$TMP/v998" && "$PMLINT" --check) >/tmp/pmlint_bad_out.txt 2>&1
rc=$?
set -e
assert_eq "pmlint --check bad exit" "$rc" "1"
if grep -q "How to fix" /tmp/pmlint_bad_out.txt && grep -q "install-pmlint" /tmp/pmlint_bad_out.txt; then
  PASS=$((PASS + 1))
  if [[ -n "$VERBOSE" ]]; then echo "  ✓ PASS: failure footer present"; fi
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL [failure footer missing How to fix / install-pmlint]")
  echo "  ✗ FAIL: failure footer incomplete"
  if [[ -n "$VERBOSE" ]]; then cat /tmp/pmlint_bad_out.txt; fi
fi
if grep -q "pmlint stages:" /tmp/pmlint_bad_out.txt && grep -q "✗ check_volume" /tmp/pmlint_bad_out.txt; then
  PASS=$((PASS + 1))
  if [[ -n "$VERBOSE" ]]; then echo "  ✓ PASS: stage rollup present"; fi
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL [stage rollup missing]")
  echo "  ✗ FAIL: stage rollup missing"
  if [[ -n "$VERBOSE" ]]; then cat /tmp/pmlint_bad_out.txt; fi
fi
rm -rf "$TMP"

# --- --fix percent then check (mutating only bib) ---
TMP=$(mktemp -d)
mkdir -p "$TMP/v997"
# Minimal volume: one paper with unescaped %
cat > "$TMP/v997/proceedings.bib" <<'EOF'
@Proceedings{FixConf2026,
  booktitle = {Proceedings of the Fix Conference},
  name = {Fix Conference 2026},
  shortname = {FC},
  year = {2026},
  editor = {Editor, A.},
  start = {1},
  end = {2},
  address = {Online},
  volume = {997},
  published = {2026-04-06}
}
@InProceedings{doe26a,
  title = {Accuracy at 50%},
  author = {Doe, Jane},
  abstract = {We get 25% better results.},
  pages = {1-2},
  year = {2026},
  booktitle = {Proceedings of the Fix Conference},
  editor = {Editor, A.},
  volume = {997}
}
EOF
# empty PDF placeholder
: > "$TMP/v997/doe26a.pdf"
set +e
(cd "$TMP/v997" && "$PMLINT" --fix) >/tmp/pmlint_fix_out.txt 2>&1
rc=$?
set -e
# After fix-percent, tidy should pass; check_volume may still pass with empty pdf
if grep -q '\\\\%' "$TMP/v997/proceedings.bib" || grep -q '\\%' "$TMP/v997/proceedings.bib"; then
  PASS=$((PASS + 1))
  if [[ -n "$VERBOSE" ]]; then echo "  ✓ PASS: --fix escaped percents"; fi
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL [--fix did not escape percents]")
  echo "  ✗ FAIL: --fix did not escape percents"
  if [[ -n "$VERBOSE" ]]; then cat /tmp/pmlint_fix_out.txt; fi
fi
rm -rf "$TMP"

# --- skip when gh-pages present (published volume) ---
TMP=$(mktemp -d)
cp -R "$FIXTURES/clean_volume" "$TMP/v996"
(
  cd "$TMP/v996"
  git init -q
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
(cd "$TMP/v996" && "$PMLINT" --check) >/tmp/pmlint_skip_out.txt 2>&1
rc=$?
set -e
assert_eq "pmlint skips published volume" "$rc" "0"
if grep -q "SKIPPED" /tmp/pmlint_skip_out.txt; then
  PASS=$((PASS + 1))
  if [[ -n "$VERBOSE" ]]; then echo "  ✓ PASS: skip message present"; fi
else
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL [missing SKIPPED message]")
  echo "  ✗ FAIL: missing SKIPPED message"
  if [[ -n "$VERBOSE" ]]; then cat /tmp/pmlint_skip_out.txt; fi
fi
set +e
(cd "$TMP/v996" && "$PMLINT" --check --force) >/tmp/pmlint_force_out.txt 2>&1
rc=$?
set -e
assert_eq "pmlint --force still lints published volume" "$rc" "0"
if grep -q "SKIPPED" /tmp/pmlint_force_out.txt; then
  FAIL=$((FAIL + 1))
  ERRORS+=("FAIL [--force should not skip]")
  echo "  ✗ FAIL: --force should not skip"
else
  PASS=$((PASS + 1))
  if [[ -n "$VERBOSE" ]]; then echo "  ✓ PASS: --force does not skip"; fi
fi
rm -rf "$TMP"

echo
echo "Passed: $PASS  Failed: $FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  printf '%s\n' "${ERRORS[@]}"
  exit 1
fi
echo "All pmlint smoke tests passed."
exit 0
