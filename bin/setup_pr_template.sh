#!/bin/bash

# Check if a volume name is provided
if [ $# -eq 0 ]; then
    echo "Please provide a volume name as an argument."
    exit 1
fi

volume_name=$1

# Check if we're in a git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: Not in a git repository"
    exit 1
fi

# Check if the remote repository matches the expected one
expected_remote="git@github.com:mlresearch/$volume_name.git"
actual_remote=$(git remote get-url origin 2>/dev/null)

if [ "$actual_remote" != "$expected_remote" ]; then
    echo "Error: Current repository remote ($actual_remote) does not match expected remote ($expected_remote)"
    echo "Please make sure you're in the correct repository."
    exit 1
fi

# Check if main branch exists
if ! git show-ref --verify --quiet refs/heads/main; then
    echo "Error: main branch does not exist"
    exit 1
fi

# Check if gh-pages branch exists
if ! git show-ref --verify --quiet refs/heads/gh-pages; then
    echo "Error: gh-pages branch does not exist"
    exit 1
fi

# Create .github directory if it doesn't exist
mkdir -p ../$volume_name/.github

# Copy the template from papersite to the volume's .github directory
cp ../papersite/pull_request_template.md ../$volume_name/.github/

# Add and commit the template to main branch
cd ../$volume_name
git checkout main
git add .github/pull_request_template.md
git commit -m "Update pull request template for paper edits"

# Also add to gh-pages branch
git checkout gh-pages
git add .github/pull_request_template.md
git commit -m "Update pull request template for paper edits"

# Switch back to main branch
git checkout main

echo "Pull request template has been updated in both main and gh-pages branches of $volume_name."
echo "Please review the changes and push when ready." 