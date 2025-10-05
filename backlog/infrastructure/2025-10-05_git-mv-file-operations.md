---
id: "2025-10-05_git-mv-file-operations"
title: "Replace FileUtils.mv with git mv for file operations"
status: "completed"
priority: "high"
created: "2025-10-05"
last_updated: "2025-10-05"
owner: "Neil D. Lawrence"
dependencies: []
tags:
- infrastructure
- git
- file-operations
- bandwidth-optimization
---

# Task: Replace FileUtils.mv with git mv for file operations

## Description
Replace `FileUtils.mv` operations with `git mv` commands in the volume creation scripts to preserve Git history and optimize bandwidth usage during file movements. This change ensures that file moves are tracked by Git and reduces bandwidth consumption for large volumes.

## Acceptance Criteria
- [x] Replace `FileUtils.mv` with `system("git mv ...")` in `lib/mlresearch.rb`
- [x] Ensure PDF file movements use `git mv` instead of `FileUtils.mv`
- [x] Ensure supplementary file movements use `git mv` instead of `FileUtils.mv`
- [x] Test with volume 267 to verify git mv operations work correctly
- [x] Verify that file history is preserved during moves

## Implementation Notes
The changes have been implemented in the following files:

### `lib/mlresearch.rb` (lines 420-421, 459-460)
```ruby
# Before (FileUtils.mv)
FileUtils.mv(ha['id'] + '.pdf', 'assets/' + filestub + '/' + filestub + '.pdf')
FileUtils.mv(supp_file, 'assets/' + filestub + '/' + newfilename)

# After (git mv)
system("git mv '#{ha['id']}.pdf' 'assets/#{filestub}/#{filestub}.pdf'")
system("git mv '#{supp_file}' 'assets/#{filestub}/#{newfilename}'")
```


## Benefits
- **Bandwidth Optimization**: Git mv operations are more efficient for large files
- **History Preservation**: File moves are tracked by Git, maintaining version history
- **Large Volume Support**: Essential for processing large volumes like v267 (3333 papers)
- **Consistency**: All file operations now use Git commands

## Testing Results
- [x] Tested with volume 267 preparation - git mv operations work correctly
- [x] Verified that file history is preserved during moves
- [x] No regression in file movement functionality
- [x] Bandwidth improvements confirmed for large file operations

## Related
- **Volume**: v267 (ICML 2025) - 3333 papers
- **Issue**: Bandwidth optimization for large volume processing
- **Files Modified**: `lib/mlresearch.rb`

## Progress Updates

### 2025-10-05
Task completed. FileUtils.mv operations successfully replaced with git mv commands in mlresearch.rb. Changes tested and verified to work correctly with volume 267 processing. All acceptance criteria met.
