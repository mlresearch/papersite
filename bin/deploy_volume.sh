#!/bin/bash

# Deploy Volume Script
# Usage: ./deploy_volume.sh <volume_number>
# Example: ./deploy_volume.sh 305

set -e  # Exit on any error

VOLUME_NUMBER=$1

if [ -z "$VOLUME_NUMBER" ]; then
    echo "Usage: $0 <volume_number>"
    echo "Example: $0 305"
    exit 1
fi

echo "Deploying volume $VOLUME_NUMBER..."

# Step 1: Add created files to main branch
echo "Step 1: Adding created files to main branch..."
git add _posts/ Gemfile *.bib _config.yml README.md index.html
git add assets/ 2>/dev/null || true

# Step 2: Copy pull request template from papersite directory
echo "Step 2: Copying pull request template..."
cp ../papersite/pull_request_template.md .github/pull_request_template.md

# Step 3: Commit changes to main
echo "Step 3: Committing changes to main..."
git add .github/pull_request_template.md
git commit -m "Add volume $VOLUME_NUMBER content and assets"

# Step 4: Create new branch gh-pages
echo "Step 4: Creating gh-pages branch..."
if git show-ref --verify --quiet refs/heads/gh-pages; then
    echo "Switching to existing gh-pages branch"
    git checkout gh-pages
else
    echo "Creating new gh-pages branch"
    git checkout -b gh-pages
fi

# Step 5: Delete assets from gh-pages
echo "Step 5: Deleting assets from gh-pages..."
git rm -r assets/ 2>/dev/null || true

# Step 6: Push gh-pages
echo "Step 6: Pushing gh-pages branch..."
git commit -m "Remove assets from volume $VOLUME_NUMBER gh-pages"
git push origin gh-pages

# Step 7: Checkout main (recovering assets)
echo "Step 7: Checking out main branch..."
git checkout main

# Step 8: Delete all apart from assets and README.md
echo "Step 8: Cleaning main branch (keeping only assets and README.md)..."
git rm -r _posts/ Gemfile *.bib _config.yml index.html 2>/dev/null || true

# Step 9: Push main
echo "Step 9: Pushing main branch..."
git commit -a -m "Clean main branch - keep only assets and README for volume $VOLUME_NUMBER"
git push origin main

echo "Deployment complete for volume $VOLUME_NUMBER!"
echo "Main branch: Contains assets and README.md"
echo "gh-pages branch: Contains Jekyll site files"
