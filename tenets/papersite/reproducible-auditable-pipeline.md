---
id: "reproducible-auditable-pipeline"
title: "Reproducible, Auditable Pipeline"
status: "Active"
created: "2026-01-19"
last_reviewed: "2026-01-19"
review_frequency: "Annual"
conflicts_with: []
tags:
- tenet
- reproducibility
- tooling
- governance
---

# Tenet: Reproducible, Auditable Pipeline

## Tenet

**Description**: Prefer workflows that can be repeated end-to-end and produce the same results from the same inputs. When a change is made, it should be attributable to an intentional, reviewable action (script, commit, CIP/backlog item), not an undocumented manual tweak.

**Quote**: *“Make it rerunnable and reviewable.”*

**Examples**:
- Use scripts (e.g., validators, tidiers, deploy helpers) to encode workflows instead of relying on remembered terminal sequences.
- Keep “why” close to changes: CIPs for HOW, backlog tasks for DO, and consistent metadata to enable automated summaries (e.g., `./whats-next`).
- Prefer deterministic transformations over interactive steps when possible; when interaction is required, capture the resulting mapping/config for future runs.

**Counter-examples**:
- A one-off manual fix to a BibTeX file that never gets encoded into the tidying pipeline.
- Tooling changes that shift behavior but aren’t reflected in governance artifacts (no corresponding CIP/backlog updates).
- “Works on my machine” operations that require an undocumented environment or hidden state.

**Conflicts**:
- **Potential conflict**: `surgical-changes-preserve-history` (sometimes reproducibility requires restructuring).
  - **Resolution**: Do restructuring in small, reviewable steps and preserve history where feasible.

