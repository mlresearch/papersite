---
category: infrastructure
created: '2025-10-07'
dependencies: []
id: 2025-10-07_updaterepo-script-improvements
last_updated: '2025-10-07'
owner: Development Team
priority: High
related_cips: []
status: Proposed
title: Improve updaterepo.sh script for better volume deployment
---

# Task: Improve updaterepo.sh script for better volume deployment

## Description

The current `updaterepo.sh` script has several issues that need to be addressed to ensure proper volume deployment:

1. **BibTeX file handling**: Currently moves ALL .bib files instead of just the original and cleaned version
2. **Assets cleanup**: Assets folder is not being removed from gh-pages branch
3. **README.md handling**: New README.md needs to be committed to main branch
4. **Pull request template**: Not being properly copied to both branches
5. **Branch management**: Doesn't handle existing gh-pages branch properly
6. **Repository naming**: PR template script fails due to repository name mismatch

## Acceptance Criteria

- [ ] Script only moves the cleaned BibTeX file (e.g., `nesy25_clean.bib`) to gh-pages, not all .bib files
- [ ] Assets folder is properly removed from gh-pages branch after moving to main
- [ ] README.md is committed to main branch before moving to gh-pages
- [ ] Pull request template is copied to both main and gh-pages branches
- [ ] Script handles existing gh-pages branch (check if exists before creating)
- [ ] Repository name mismatch in PR template script is resolved
- [ ] Script works correctly for both v267 and v284 volumes
- [ ] All Jekyll files are properly organized between branches

## Implementation Notes

### BibTeX File Handling
```bash
# Instead of: mv *.bib gh-pages_files/
# Use: mv *cleaned.bib gh-pages_files/
```

### Assets Cleanup
```bash
# After moving assets to main, remove from gh-pages
git rm -r assets/ 2>/dev/null || true
```

### README.md Handling
```bash
# Commit README.md to main before moving to gh-pages
git add README.md
git commit -m "Update README.md for volume $volume_name"
```

### Pull Request Template
```bash
# Copy template to both branches
cp pull_request_template.md gh-pages_files/
git add pull_request_template.md
```

### Branch Management
```bash
# Check if gh-pages branch exists
if git show-ref --verify --quiet refs/heads/gh-pages; then
    git checkout gh-pages
else
    git checkout -b gh-pages
fi
```

## Related

- **CIP-0002**: Testing framework improvements
- **CIP-0003**: BibTeX file format validation
- **Backlog**: 2025-10-05_github-action-bibtex-testing.md

## Benefits

- **Cleaner deployments**: Proper separation of assets and Jekyll files
- **Better organization**: Assets stay in main, Jekyll files in gh-pages
- **Consistent templates**: PR template available in both branches
- **Robust handling**: Works with existing branches and different volume names
- **Maintainable**: Clear separation of concerns between branches

## Testing Strategy

1. Test with v267 volume (existing)
2. Test with v284 volume (new)
3. Test with existing gh-pages branch
4. Test with new gh-pages branch
5. Verify assets are only in main branch
6. Verify Jekyll files are only in gh-pages branch
7. Verify README.md is in both branches
8. Verify pull request template is in both branches

## Progress Updates

### 2025-10-07
Task created with Proposed status. Identified key issues with current script:
- BibTeX file handling issues
- Assets cleanup problems
- README.md not committed to main
- Pull request template not copied to both branches
- Branch management issues
- Repository naming problems
