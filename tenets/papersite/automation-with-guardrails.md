---
id: "automation-with-guardrails"
title: "Automation With Guardrails"
status: "Active"
created: "2026-01-19"
last_reviewed: "2026-01-19"
review_frequency: "Annual"
conflicts_with: []
tags:
- tenet
- automation
- safety
- tooling
---

# Tenet: Automation With Guardrails

## Tenet

**Description**: Automate routine, repeatable work, but make risky actions explicit and hard to do accidentally. Prefer scripts that are safe-by-default, with clear flags for destructive operations, and outputs that help diagnose failures quickly.

**Quote**: *“Automate the boring; guard the dangerous.”*

**Examples**:
- Validation scripts that default to read-only “check” modes and require `--fix` for mutations.
- Deploy scripts that print clear step-by-step status and fail fast when invariants are violated.
- Tools that distinguish system vs. user content so “updates” don’t overwrite project artifacts.

**Counter-examples**:
- A deploy script that deletes or rewrites branch contents without an explicit, reviewable plan.
- “Fix” modes that silently rewrite many files without a summary of what changed.
- Workflows that can proceed despite detected validation errors.

**Conflicts**:
- **Potential conflict**: `data-integrity-over-convenience` (guardrails can slow down quick remediation).
  - **Resolution**: Keep guardrails lightweight and make the safe path the fastest path (good diagnostics, targeted fixes).

