---
id: "0002"
title: "Core tooling has repeatable, easy-to-run automated tests"
status: "In Progress"
priority: "Medium"
created: "2026-01-19"
last_updated: "2026-01-19"
related_tenets:
- "reproducible-auditable-pipeline"
- "automation-with-guardrails"
stakeholders:
- "Repository maintainers"
- "Contributors"
tags:
- "testing"
- "ruby"
- "ci"
---

# REQ-0002: Core tooling has repeatable, easy-to-run automated tests

## Description

Project tooling (scripts and libraries that transform or validate publication data) must be covered by automated tests that are straightforward to run and interpret. This reduces regression risk, supports safe refactoring, and provides confidence when changing data-processing logic.

**Why this matters**: Supports `reproducible-auditable-pipeline` by making correctness checkable and repeatable, and supports `automation-with-guardrails` by catching unsafe changes before they affect releases.

**Who benefits**: Maintainers and contributors developing or modifying scripts, and volume editors relying on stable pipeline behavior.

## Acceptance Criteria

- [ ] There is a documented, repeatable way to run automated tests for core scripts/libraries (single command or clearly documented steps).
- [ ] Test output clearly indicates pass/fail status and provides actionable failure information.
- [ ] At least one critical data-quality tool has meaningful automated coverage (not just a “smoke test”).
- [ ] Project test conventions (where tests live, naming, how to add a test) are documented for contributors.

## Notes (Optional)

This requirement does not mandate a specific testing framework; it mandates that tests exist, are runnable, and provide useful regression detection.

## References

- **Related Tenets**: `reproducible-auditable-pipeline`, `automation-with-guardrails`
- **Related CIP(s)**: CIP-0002 (Testing framework and conventions)

## Progress Updates

### 2026-01-19
Requirement recorded based on ongoing testing framework work described in CIP-0002.

