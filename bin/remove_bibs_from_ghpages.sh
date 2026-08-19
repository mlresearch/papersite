#!/bin/bash
# Remove .bib files from gh-pages branch of all local volume repos.
# Bib files are preserved in git history (committed before removal).
# Safe to re-run: skips volumes with no tracked bib files.

set -uo pipefail

BASE=/Users/neil/mlresearch
COMMIT_MSG="Remove bib files from gh-pages - not part of rendered output, retrieve via git history if needed"

ok=0
skipped=0
failed=0
failed_list=()

for dir in "$BASE"/v[0-9]*/; do
    [[ "$dir" == *permissions* ]] && continue
    [ ! -d "${dir}.git" ] && continue

    volname=$(basename "$dir")

    # Check for tracked bib files on gh-pages before doing anything
    bibs=$(git -C "$dir" ls-tree --name-only gh-pages 2>/dev/null | grep '\.bib$') || true
    if [ -z "$bibs" ]; then
        echo "[$volname] skip - no bib files on gh-pages"
        skipped=$((skipped + 1))
        continue
    fi

    echo ""
    echo "[$volname] processing..."

    # Save current branch so we can restore it
    orig_branch=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null || echo "DETACHED")

    # Checkout and sync gh-pages with remote
    echo "  → syncing gh-pages"
    if ! git -C "$dir" checkout gh-pages -q 2>/dev/null; then
        echo "  → failed to checkout gh-pages, skipping"
        failed=$((failed + 1))
        failed_list+=("$volname")
        continue
    fi
    # Use fetch + reset to handle any non-fast-forward situation cleanly
    git -C "$dir" fetch origin gh-pages -q 2>/dev/null || echo "  → fetch failed, proceeding with local state"
    git -C "$dir" reset --hard origin/gh-pages -q 2>/dev/null || echo "  → reset failed, proceeding with local state"

    # Remove bib files
    bib_list=$(git -C "$dir" ls-files '*.bib')
    if [ -z "$bib_list" ]; then
        echo "  → no bib files tracked after sync, skipping commit"
        git -C "$dir" checkout "$orig_branch" -q 2>/dev/null || true
        skipped=$((skipped + 1))
        continue
    fi

    echo "  → removing: $bib_list"
    git -C "$dir" rm --quiet *.bib

    git -C "$dir" commit -m "$COMMIT_MSG" -q
    echo "  → pushing"
    if ! git -C "$dir" push origin gh-pages -q; then
        echo "  → push failed for $volname"
        failed=$((failed + 1))
        failed_list+=("$volname")
        git -C "$dir" checkout "$orig_branch" -q 2>/dev/null || true
        continue
    fi

    # Restore original branch
    git -C "$dir" checkout "$orig_branch" -q 2>/dev/null || true

    echo "  ✓ done"
    ok=$((ok + 1))
done

echo ""
echo "========================================"
echo "Complete: $ok removed, $skipped skipped"
if [ "$failed" -gt 0 ]; then
    echo "Failed ($failed): ${failed_list[*]}"
fi
echo "========================================"
