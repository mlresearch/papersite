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

git remote add origin git@github.com:mlresearch/$1.git
git remote -v
git push -u origin gh-pages

# Create and switch to main branch
git checkout -b main
git rm _posts Gemfile *.bib _config.yml README.md index.html

# Add and commit pdfs
for letter in {a..z}
do git add assets/$letter*
   git commit -a -m "Add $volume_name pdfs begining with $letter"
   if git push -u origin main; then
       continue
   else
       break
   fi
done
