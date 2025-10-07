---
id: 2025-10-07_new-deploy-script
title: Create New Deploy Volume Script
status: Completed
priority: High
created: "2025-10-07"
last_updated: "2025-10-07"
owner: "Neil Lawrence"
dependencies: []
---

# Task: Create New Deploy Volume Script

## Description

Create a new deployment script that properly handles the separation of assets and Jekyll content between main and gh-pages branches. The current `updaterepo.sh` script has issues with file handling and branch management.

## Acceptance Criteria

- [x] Script adds created files to main branch
- [x] Script copies pull request template from papersite directory to .github/
- [x] Script commits changes to main branch
- [x] Script creates or switches to gh-pages branch
- [x] Script deletes assets from gh-pages branch
- [x] Script pushes gh-pages branch with Jekyll content
- [x] Script checks out main branch (recovering assets)
- [x] Script deletes all files except assets and README.md from main
- [x] Script pushes cleaned main branch
- [x] Script provides clear status messages for each step
- [x] Script handles errors gracefully with proper exit codes

## Implementation Notes

The new script should follow this workflow:
1. Add created files to main branch
2. Copy pull request template from papersite directory
3. Commit changes to main
4. Create/switch to gh-pages branch
5. Delete assets from gh-pages
6. Push gh-pages branch
7. Checkout main (recovering assets)
8. Delete non-asset files from main
9. Push main branch

This approach ensures:
- Clear separation: Main has assets, gh-pages has Jekyll content
- Proper git workflow: Each branch has its specific purpose
- No confusion: No mixed content in branches
- Bandwidth efficient: Assets only in main, Jekyll only in gh-pages

## Related

- Current script: `bin/updaterepo.sh`
- New script: `bin/deploy_volume.sh`

## Progress Updates

### 2025-10-07
Task created with Proposed status. New deploy script created with improved workflow for proper branch separation.

### 2025-10-07
Task completed. New deploy_volume.sh script implemented with proper branch separation workflow. Old updaterepo.sh script removed.
