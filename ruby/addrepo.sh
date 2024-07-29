#!/bin/bash

# Check if a volume name is provided
if [ $# -eq 0 ]; then
    echo "Please provide a volume name as an argument."
    exit 1
fi

volume_name=$1

git init

# Create and switch to gh-pages branch
git checkout -b gh-pages

# Add and commit files
git add _posts Gemfile *.bib _config.yml README.md index.html
git commit -m "Add pages for volume $volume_name"

# Create and switch to main branch
git checkout -b main
git add _posts Gemfile *.bib _config.yml README.md index.html

# Add and commit pdfs
git add assets
git commit -m "Add assets for volume $volume_name"

# Add remote repository 
git remote add origin git@github.com:mlresearch/$1.git
git remote -v

# Push both branches
git push -u origin gh-pages
git push -u origin main
echo "Repository created and pushed to GitHub."
