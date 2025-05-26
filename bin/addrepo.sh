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

git init

# Create and switch to gh-pages branch
git checkout -b gh-pages

# Add and commit files
files_to_add=("_posts" "Gemfile" "_config.yml" "README.md" "index.html")
bib_files=(*.bib)
log_files=(*.log)

for file in "${files_to_add[@]}"; do
    if [ -e "$file" ]; then
        git add "$file"
    else
        echo "Warning: $file not found, skipping..."
    fi
done

# Add .bib files if they exist
if [ ${#bib_files[@]} -gt 0 ] && [ "${bib_files[0]}" != "*.bib" ]; then
    git add "${bib_files[@]}"
else
    echo "Warning: No .bib files found, skipping..."
fi

# Add .log files if they exist
if [ ${#log_files[@]} -gt 0 ] && [ "${log_files[0]}" != "*.log" ]; then
    git add "${log_files[@]}"
else
    echo "Warning: No .log files found, skipping..."
fi

git commit -m "Add pages for volume $volume_name"

# Add remote repository 
git remote add origin git@github.com:mlresearch/$1.git
git remote -v

# Push gh-pages
git push -u origin gh-pages

# Move gh-pages files out of the way.
mkdir gh-pages_files
mv _posts Gemfile *.bib _config.yml README.md index.html gh-pages_files

# Create and switch to main branch
git checkout -b main

# Add and commit pdfs
git add assets
git commit -a -m "Add assets for volume $volume_name"

git push -u origin main
echo "Repository created and pushed to GitHub."

git commit -a -m "Remove gh-pages files"
git push
