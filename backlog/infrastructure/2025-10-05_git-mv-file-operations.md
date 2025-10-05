---
id: "2025-10-05_git-mv-file-operations"
title: "Replace FileUtils.mv with git mv for file operations"
status: "ready"
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
- [ ] Replace `FileUtils.mv` with `system("git mv ...")` in `lib/mlresearch.rb`
- [ ] Replace `FileUtils.mv` with `system("git mv ...")` in `lib/old-mlresearch.rb`
- [ ] Ensure PDF file movements use `git mv` instead of `FileUtils.mv`
- [ ] Ensure supplementary file movements use `git mv` instead of `FileUtils.mv`
- [ ] Test with volume 267 to verify git mv operations work correctly
- [ ] Verify that file history is preserved during moves

## Implementation Notes
The changes need to be made in the following files:

### `lib/mlresearch.rb` (lines 420-421, 459-460)
```ruby
# Current (FileUtils.mv)
FileUtils.mv(ha['id'] + '.pdf', 'assets/' + filestub + '/' + filestub + '.pdf')
FileUtils.mv(supp_file, 'assets/' + filestub + '/' + newfilename)

# Target (git mv)
system("git mv '#{ha['id']}.pdf' 'assets/#{filestub}/#{filestub}.pdf'")
system("git mv '#{supp_file}' 'assets/#{filestub}/#{newfilename}'")
```

### `lib/old-mlresearch.rb`
Similar changes need to be applied to maintain consistency across both files.

## Benefits
- **Bandwidth Optimization**: Git mv operations are more efficient for large files
- **History Preservation**: File moves are tracked by Git, maintaining version history
- **Large Volume Support**: Essential for processing large volumes like v267 (3333 papers)
- **Consistency**: All file operations will use Git commands

## Testing Strategy
- Test with volume 267 to verify git mv operations work correctly
- Verify that file history is preserved during moves
- Ensure no regression in file movement functionality
- Validate bandwidth improvements for large file operations

## Related
- **Volume**: v267 (ICML 2025) - 3333 papers
- **Issue**: Bandwidth optimization for large volume processing
- **Files to be Modified**: `lib/mlresearch.rb`, `lib/old-mlresearch.rb`
