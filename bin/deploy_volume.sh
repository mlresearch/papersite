#!/bin/bash

# ============================================================================
# Deploy Volume Script - PMLR Two-Branch Deployment Strategy
# ============================================================================
#
# PURPOSE:
#   Deploys a PMLR volume using a two-branch strategy that separates:
#   - main branch: Contains only PDFs (assets/) and README.md
#   - gh-pages branch: Contains only Jekyll site files (for GitHub Pages)
#
# USAGE:
#   cd ~/mlresearch/vNNN        # MUST run from volume directory
#   ../papersite/bin/deploy_volume.sh NNN
#
# WHAT THIS SCRIPT DOES:
#   1. Commits all generated files (Jekyll + assets) to main branch
#   2. Creates/updates gh-pages branch with Jekyll files (removes assets)
#   3. Cleans main branch to keep only assets and README.md
#   4. Pushes both branches to GitHub
#
# WHY TWO BRANCHES?
#   - GitHub Pages (gh-pages) serves the website without large PDF files
#   - Main branch serves PDFs via raw.githubusercontent.com URLs
#   - Keeps repository sizes manageable and hosting efficient
#
# REQUIREMENTS:
#   - Must be run from a volume directory (e.g., v278/)
#   - Volume must have been processed with create_volume.rb
#   - Git repository must be initialized and have a remote
#
# WARNING:
#   This script PUSHES to GitHub! Make sure you're ready to publish.
#
# ============================================================================N

set -e  # Exit on any error

VOLUME_NUMBER=$1

# Check if volume number is provided
if [ -z "$VOLUME_NUMBER" ]; then
    echo "Error: Volume number required"
    echo ""
    echo "Usage: $0 <volume_number>"
    echo "Example: $0 278"
    echo ""
    echo "This script must be run from the volume directory:"
    echo "  cd ~/mlresearch/v278"
    echo "  ../papersite/bin/deploy_volume.sh 278"
    exit 1
fi

# Safety Check 1: Verify we're in a git repository
if [ ! -d ".git" ]; then
    echo "Error: Not in a git repository"
    echo "This script must be run from the root of a volume repository (e.g., v278/)"
    exit 1
fi

# Safety Check 2: Verify expected files exist (created by create_volume.rb)
if [ ! -d "_posts" ] || [ ! -f "_config.yml" ] || [ ! -d "assets" ]; then
    echo "Error: Missing expected files (_posts/, _config.yml, assets/)"
    echo "Have you run create_volume.rb to generate the Jekyll site?"
    exit 1
fi

# Safety Check 3: Verify we're not in the papersite directory
if [ -f "lib/create_volume.rb" ]; then
    echo "Error: This script should not be run from the papersite directory"
    echo "Please cd to the volume directory (e.g., cd ~/mlresearch/v278)"
    exit 1
fi

# Safety Check 4: Verify git remote exists
if ! git remote get-url origin &>/dev/null; then
    echo "Error: No git remote 'origin' configured"
    echo "Please set up a remote before deploying"
    exit 1
fi

echo "=========================================="
echo "PMLR Volume Deployment"
echo "=========================================="
echo "Volume: $VOLUME_NUMBER"
echo "Directory: $(pwd)"
echo "Remote: $(git remote get-url origin)"
echo ""
echo "This will:"
echo "  1. Commit Jekyll files and assets to main"
echo "  2. Create/update gh-pages with Jekyll files only"
echo "  3. Clean main to keep only assets and README"
echo "  4. PUSH both branches to GitHub"
echo ""
read -p "Continue? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Deployment cancelled"
    exit 0
fi

echo ""
echo "Deploying volume $VOLUME_NUMBER..."

# ============================================================================
# Phase 1: Commit Everything to Main Branch
# ============================================================================

# Step 1: Stage all generated files (Jekyll + assets + BibTeX)
echo "Step 1: Staging generated files on main branch..."
git add _posts/ Gemfile *.bib _config.yml README.md index.html
git add assets/ 2>/dev/null || true

# Step 2: Add PR template for GitHub workflow
echo "Step 2: Adding pull request template..."
mkdir -p .github
cp ../papersite/pull_request_template.md .github/pull_request_template.md

# Step 3: Commit everything to main
echo "Step 3: Committing all files to main..."
git add .github/pull_request_template.md
git commit -m "Add volume $VOLUME_NUMBER content and assets"

# ============================================================================
# Phase 2: Create gh-pages Branch (Jekyll Site Only)
# ============================================================================

# Step 4: Switch to or create gh-pages branch
echo "Step 4: Switching to gh-pages branch..."
if git show-ref --verify --quiet refs/heads/gh-pages; then
    echo "  → Using existing gh-pages branch"
    git checkout gh-pages
else
    echo "  → Creating new gh-pages branch"
    git checkout -b gh-pages
fi

# Step 5: Remove assets from gh-pages (GitHub Pages doesn't need PDFs)
echo "Step 5: Removing assets from gh-pages..."
echo "  → PDFs will be served from main branch only"
git rm -r assets/ 2>/dev/null || true

# Step 6: Commit and push gh-pages
echo "Step 6: Pushing gh-pages to GitHub..."
git commit -m "Remove assets from volume $VOLUME_NUMBER gh-pages" || echo "  → No changes to commit"
git push origin gh-pages

# ============================================================================
# Phase 3: Clean Main Branch (Assets + README Only)
# ============================================================================

# Step 7: Return to main branch
echo "Step 7: Returning to main branch..."
git checkout main

# Step 8: Remove Jekyll files from main (keep only assets and README)
echo "Step 8: Cleaning main branch..."
echo "  → Removing Jekyll files (keeping assets and README)"
git rm -r _posts/ Gemfile *.bib _config.yml index.html 2>/dev/null || true
git rm -r .github/ 2>/dev/null || true

# Step 9: Commit and push cleaned main branch
echo "Step 9: Pushing cleaned main to GitHub..."
git commit -a -m "Clean main branch - keep only assets and README for volume $VOLUME_NUMBER"
git push origin main

# ============================================================================
# Deployment Complete
# ============================================================================

echo ""
echo "=========================================="
echo "✓ Deployment Complete!"
echo "=========================================="
echo "Volume: $VOLUME_NUMBER"
echo ""
echo "Branch Structure:"
echo "  • main branch: Assets (PDFs) + README.md"
echo "  • gh-pages branch: Jekyll site files"
echo ""
echo "GitHub Pages will be available at:"
echo "  https://mlresearch.github.io/v$VOLUME_NUMBER/"
echo ""

