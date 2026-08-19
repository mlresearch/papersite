#!/bin/bash
# Push the current pull_request_template.md to all local volume repos.
# Updates gh-pages (where GitHub reads PR templates for these repos).
# Skips repos where the template is already up to date.
# Safe to re-run.

BASE=/Users/neil/mlresearch
TEMPLATE="$BASE/papersite/pull_request_template.md"
COMMIT_MSG="Update pull request template"

if [ ! -f "$TEMPLATE" ]; then
    echo "Error: template not found at $TEMPLATE"
    exit 1
fi

ok=0
skipped=0
failed=0
failed_list=()

for dir in "$BASE"/v[0-9]*/; do
    [[ "$dir" == *permissions* ]] && continue
    [ ! -d "${dir}.git" ] && continue
    volname=$(basename "$dir")

    # Save current branch
    orig_branch=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null || echo "gh-pages")

    # Sync gh-pages
    if ! git -C "$dir" checkout gh-pages -q 2>/dev/null; then
        echo "[$volname] skip - no gh-pages branch"
        skipped=$((skipped + 1))
        continue
    fi
    git -C "$dir" fetch origin gh-pages -q 2>/dev/null || true
    git -C "$dir" reset --hard origin/gh-pages -q 2>/dev/null || true

    # Check if template is already current
    existing=$(git -C "$dir" show gh-pages:.github/pull_request_template.md 2>/dev/null || echo "")
    current=$(cat "$TEMPLATE")
    if [ "$existing" = "$current" ]; then
        git -C "$dir" checkout "$orig_branch" -q 2>/dev/null || true
        skipped=$((skipped + 1))
        continue
    fi

    # Write updated template
    mkdir -p "${dir}.github"
    cp "$TEMPLATE" "${dir}.github/pull_request_template.md"
    git -C "$dir" add .github/pull_request_template.md

    if ! git -C "$dir" diff --cached --quiet; then
        git -C "$dir" commit -m "$COMMIT_MSG" -q
        if git -C "$dir" push origin gh-pages -q; then
            echo "[$volname] ✓ updated"
            ok=$((ok + 1))
        else
            echo "[$volname] push failed"
            failed=$((failed + 1))
            failed_list+=("$volname")
        fi
    else
        skipped=$((skipped + 1))
    fi

    git -C "$dir" checkout "$orig_branch" -q 2>/dev/null || true
done

echo ""
echo "========================================"
echo "Complete: $ok updated, $skipped skipped"
[ "$failed" -gt 0 ] && echo "Failed ($failed): ${failed_list[*]}"
echo "========================================"
