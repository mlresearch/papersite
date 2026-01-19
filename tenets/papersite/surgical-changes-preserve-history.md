---
id: "surgical-changes-preserve-history"
title: "Surgical Changes, Preserve History"
status: "Active"
created: "2026-01-19"
last_reviewed: "2026-01-19"
review_frequency: "Annual"
conflicts_with: []
tags:
- tenet
- git
- maintainability
- reviewability
---

# Tenet: Surgical Changes, Preserve History

## Tenet

**Description**: Prefer minimal, targeted changes that are easy to review and easy to revert. Preserve Git history for moves and transformations so the repository remains auditable over time. Avoid broad operations that accidentally scoop up unrelated files.

**Quote**: *“Small diffs, clear intent.”*

**Examples**:
- Use `git mv` (vs. raw filesystem moves) to preserve history for asset and supplement file movements.
- Stage and commit changes surgically (only the files relevant to the change), especially around generated/system scaffolding.
- Make metadata normalization changes in a single, deliberate pass rather than piecemeal edits across many files.

**Counter-examples**:
- Bulk staging/committing that mixes system scaffolding, user content, and unrelated edits.
- Rewriting large files without need, obscuring what changed and why.
- Moving files with tools that lose history, making it hard to track provenance.

**Conflicts**:
- **Potential conflict**: `clean-branch-separation` (branch separation can require larger moves).
  - **Resolution**: Prefer history-preserving moves and isolate branch management changes to dedicated scripts/commits.

