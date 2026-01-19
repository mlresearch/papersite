---
id: "clean-branch-separation"
title: "Clean Branch Separation"
status: "Active"
created: "2026-01-19"
last_reviewed: "2026-01-19"
review_frequency: "Annual"
conflicts_with: []
tags:
- tenet
- deployment
- git
- jekyll
---

# Tenet: Clean Branch Separation

## Tenet

**Description**: Keep generated site content and heavy assets cleanly separated to avoid drift, bloated history, and confusing deployments. Branches (or outputs) should have a single clear purpose, and automation should enforce that separation.

**Quote**: *“One branch, one job.”*

**Examples**:
- `main` holds assets; `gh-pages` holds Jekyll/site content. Automation enforces the contract each time.
- Deployment tooling removes out-of-scope files for the target branch (e.g., assets removed from `gh-pages`).
- PR templates and lightweight metadata exist where needed without dragging heavy artifacts into the wrong branch.

**Counter-examples**:
- Mixing assets and generated site content across branches, causing deployments to diverge from the intended structure.
- Scripts that “mostly” clean branches but leave stale artifacts behind, resulting in hard-to-debug discrepancies.
- Treating branch content as incidental rather than a maintained interface/contract.

**Conflicts**:
- **Potential conflict**: `surgical-changes-preserve-history` (enforcing separation can require larger structural edits).
  - **Resolution**: Implement separation with tooling and clear steps; isolate structural changes and preserve history where possible.

