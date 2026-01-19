---
id: "0001"
title: "BibTeX inputs are ASCII-only before downstream processing"
status: "Implemented"
priority: "High"
created: "2026-01-19"
last_updated: "2026-01-19"
related_tenets:
- "data-integrity-over-convenience"
- "reproducible-auditable-pipeline"
stakeholders:
- "Volume editors"
- "Repository maintainers"
tags:
- "bibtex"
- "unicode"
- "preprocessing"
---

# REQ-0001: BibTeX inputs are ASCII-only before downstream processing

## Description

BibTeX inputs used by the volume creation pipeline must be normalized such that downstream processing consumes ASCII-only `.bib` content. This reduces parsing edge cases and avoids scattering Unicode-handling logic throughout later pipeline steps.

**Why this matters**: Supports `data-integrity-over-convenience` by making malformed/ambiguous inputs explicit, and supports `reproducible-auditable-pipeline` by ensuring a consistent, repeatable preprocessing stage.

**Who benefits**: Volume editors preparing releases, and maintainers who need reliable, debuggable conversions.

## Acceptance Criteria

- [ ] Given a BibTeX file containing non-ASCII characters, there exists a repeatable preprocessing step that produces an ASCII-only BibTeX output.
- [ ] The preprocessing step supports persistent replacement mappings so repeated runs converge to the same normalized output for the same inputs.
- [ ] Downstream processing stages do not require ad-hoc Unicode replacement logic to succeed on normalized files.
- [ ] When non-ASCII input is encountered, the workflow produces a clear, reviewable record of the replacements applied (e.g., via a mapping file or equivalent artifact).

## Notes (Optional)

This requirement focuses on the desired state (ASCII-only downstream inputs). Specific tooling choices (script language, flags, integration points) belong in CIPs and backlog tasks.

## References

- **Related Tenets**: `data-integrity-over-convenience`, `reproducible-auditable-pipeline`
- **Related CIP(s)**: CIP-0001 (Unicode tidying preprocessing step)

## Progress Updates

### 2026-01-19
Requirement recorded based on existing Unicode tidying work described in CIP-0001.

