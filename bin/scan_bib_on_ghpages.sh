#!/bin/bash
# Scan all local volume repos for .bib files tracked on gh-pages
BASE=/Users/neil/mlresearch
found=0
for dir in "$BASE"/v[0-9]*/; do
    [[ "$dir" == *permissions* ]] && continue
    [ ! -d "${dir}.git" ] && continue
    volname=$(basename "$dir")
    bibs=$(git -C "$dir" ls-tree --name-only gh-pages 2>/dev/null | grep '\.bib$')
    if [ -n "$bibs" ]; then
        echo "$volname: $bibs"
        found=$((found + 1))
    fi
done
echo ""
echo "Total volumes with bib files on gh-pages: $found"
