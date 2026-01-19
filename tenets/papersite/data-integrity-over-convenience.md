---
id: "data-integrity-over-convenience"
title: "Data Integrity Over Convenience"
status: "Active"
created: "2026-01-19"
last_reviewed: "2026-01-19"
review_frequency: "Annual"
conflicts_with: []
tags:
- tenet
- data-quality
- bibtex
- validation
---

# Tenet: Data Integrity Over Convenience

## Tenet

**Description**: Prefer correct, validated artifacts over shortcuts. If a pipeline step can silently produce wrong output (or output that “looks right” but is inconsistent), we treat that as worse than a hard failure. Data hygiene (especially BibTeX) is the foundation for reliable volume generation and downstream indexing.

**Quote**: *“If it isn’t validated, it isn’t done.”*

**Examples**:
- Run tidying/validation (e.g., Unicode tidying, BibTeX cleaning) before conversion steps so downstream processing only sees well-formed inputs.
- When adding new Unicode replacements, include tests or checks to prevent regressions and ensure replacements are applied consistently.
- Prefer structured frontmatter normalization (statuses, required fields) to reduce ambiguity and tooling drift.

**Counter-examples**:
- Skipping validation because a volume “mostly works,” then debugging a downstream failure caused by malformed BibTeX.
- Allowing ambiguous statuses (`completed`, `in-progress`) to persist in CIPs/backlog, making automation unreliable.
- Applying ad-hoc manual edits to generated artifacts without capturing the transformation as a repeatable step.

**Conflicts**:
- **Potential conflict**: `automation-with-guardrails` (guardrails can slow “quick fixes”).
  - **Resolution**: Allow fast iteration, but ensure the final path includes validation (ideally automated).

