---
id: "0005"
title: "Post-publication paper YAML edits are validated before merge"
status: "Proposed"
priority: "High"
created: "2026-10-04"
last_updated: "2026-10-04"
related_tenets:
- "data-integrity-over-convenience"
- "automation-with-guardrails"
- "reproducible-auditable-pipeline"
stakeholders:
- "Volume editors"
- "Authors correcting published papers"
- "Repository maintainers"
tags:
- "jekyll"
- "yaml"
- "posts"
- "pull-requests"
- "data-quality"
---

# REQ-0005: Post-publication paper YAML edits are validated before merge

> **Remember**: Requirements describe **WHAT** should be true (outcomes), not HOW to achieve it.

## Description

After a PMLR volume is published, corrections to individual papers are made by editing the Jekyll paper files under `_posts/` (the FAQ path). Those edits must be checked before merge so that invalid YAML, broken frontmatter, and inconsistent citation fields do not reach the live site.

Intake validation of BibTeX and PDF placement (REQ-0003 / CIP-0008) remains the gate for *new* volumes. This requirement covers the *published* correction path, where `.bib` files are often absent from the working tree and the rendered site is driven only by `_posts`.

**Why this matters**: Supports `data-integrity-over-convenience` by failing hard on bad post edits instead of discovering them after Pages rebuild or via downstream citeproc consumers. Supports `automation-with-guardrails` by making the check the default PR gate, not a remembered manual step.

**Who benefits**: Editors and authors fixing titles/authors/abstracts; maintainers reviewing correction PRs; readers and index consumers who depend on well-formed posts.

## Acceptance Criteria

- [ ] A pull request that changes `_posts/` on a published volume is checked automatically before merge.
- [ ] Invalid YAML / frontmatter that would break Jekyll (or citeproc-style consumers) fails the check with an actionable message identifying the file.
- [ ] Posts are checked against the documented paper frontmatter contract (required keys and shapes the theme expects).
- [ ] Within-post citation consistency is checked where the post carries both display and BibTeX-derived fields (e.g. display `author`/`title` vs `bibtex_author` / related fields), without requiring a live `.bib` on the branch.
- [ ] Known classes of silent corruption (e.g. non-printable / bad UTF-8 in text fields) fail the check.
- [ ] Bypass requires explicit intent; a clean published volume with no `_posts` changes is not forced through intake BibTeX lint.

## Notes (Optional)

HOW (tooling, CLI flags, workflow wiring) belongs in CIP-0009. Fleet enablement across existing volume repositories is a separate outcome and should not block defining this requirement.

## References

- **Related Tenets**: `data-integrity-over-convenience`, `automation-with-guardrails`, `reproducible-auditable-pipeline`
- **FAQ / editor guidance**: https://proceedings.mlr.press/faq.html
- **Frontmatter contract notes**: [CIP-0005](../cip/cip0005.md) (theme + `_posts` keys)
- **Contrast**: [REQ-0003](req0003_bibtex-validation-prevents-pipeline-failures.md) (pre-publication BibTeX)

## Progress Updates

### 2026-10-04
Requirement recorded; CIP-0009 proposed as the HOW.
