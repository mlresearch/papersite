#!/bin/bash

# Check if a volume name is provided
if [ $# -eq 0 ]; then
    echo "Please provide a volume name as an argument."
    exit 1
fi

volume_name=$1

# Ensure we're on main branch
git checkout main

# Create temporary directory for gh-pages files
mkdir -p gh-pages_files

# Move Jekyll-related files to temporary directory
mv _posts Gemfile *.bib _config.yml README.md index.html gh-pages_files/ 2>/dev/null || true

# Commit any remaining changes to main (PDFs and binaries)
git add assets
git commit -m "Update assets for volume $volume_name" || true

# Push main branch
git push origin main

# Switch to gh-pages branch
git checkout -b gh-pages

# Move files from temporary directory to current directory
mv gh-pages_files/* . 2>/dev/null || true
rmdir gh-pages_files

# Add and commit Jekyll files
git add _posts Gemfile *.bib _config.yml README.md index.html
git commit -m "Update pages for volume $volume_name"

# Push gh-pages branch
git push origin gh-pages

# Switch back to main branch
git checkout main

echo "Repository updated successfully."

# Get the directory where the current script is located
script_dir=$(dirname "$0")

# Update the pull request template
"$script_dir/setup_pr_template.sh" $volume_name 
