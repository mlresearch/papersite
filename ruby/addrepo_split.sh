#!/bin/bash

# Check if a volume name is provided
if [ $# -eq 0 ]; then
    echo "Please provide a volume name as an argument."
    exit 1
fi

volume_name=$1

# Check if repository already exists
if git ls-remote "git@github.com:mlresearch/$volume_name.git" &>/dev/null; then
    echo "Repository $volume_name already exists on GitHub."
    echo "Please use ./updaterepo.sh instead to update an existing repository."
    exit 1
fi

# Step 1: Create gh-pages branch
echo "Step 1: Creating gh-pages branch..."
git init
git checkout -b gh-pages

# Add and commit files
git add _posts Gemfile *.bib _config.yml README.md index.html
git commit -m "Add pages for volume $volume_name"

# Add remote repository 
git remote add origin git@github.com:mlresearch/$1.git
git remote -v

# Push gh-pages
git push -u origin gh-pages

# Move gh-pages files out of the way.
mkdir gh-pages_files
mv _posts Gemfile *.bib _config.yml README.md index.html gh-pages_files

echo "Step 1 complete. gh-pages branch has been created and pushed."
echo "Please run the following commands when ready to proceed with Step 2:"
echo "git checkout -b main"
echo "git add assets"
echo "git commit -m \"Add assets for volume $volume_name\""
echo "git push -u origin main"
echo "git commit -a -m \"Remove gh-pages files\""
echo "git push"
