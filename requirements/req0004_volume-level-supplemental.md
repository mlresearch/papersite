---
id: "0004"
title: "Volume-level supplemental material is visible on the proceedings page"
status: "In Progress"
priority: "Medium"
created: "2026-08-19"
last_updated: "2026-08-19"
related_tenets:
- "data-integrity-over-convenience"
- "clean-branch-separation"
- "reproducible-auditable-pipeline"
stakeholders:
- "Readers"
- "Volume editors"
- "Repository maintainers"
tags:
- "jekyll"
- "extras"
- "historical-volumes"
- "challenge-proceedings"
---

# REQ-0004: Volume-level supplemental material is visible on the proceedings page

## Description

When a PMLR volume includes supplemental files that were stored as volume-level W&CP leftovers (`supplemental/` plus `supplementalurl`) rather than as `{id}-supp.*` paper extras, those files must still be reachable from the public volume page. The durable outcome is the modern extras path: files named and attached like other paper supplements, so they appear next to the paper that cites them.

**Why this matters**: Missing links are a form of silent data loss. The files can exist in the repository and even be served by GitHub Pages, yet remain invisible. That violates `data-integrity-over-convenience`. New volumes already use `{id}-supp.*`; historical challenge volumes should be moved onto that convention rather than growing a second extras mechanism.

**Who benefits**: Readers looking for challenge dataset and software reports; editors of challenge volumes; maintainers closing long-standing link bugs.

## Acceptance Criteria

- [ ] Challenge appendices that currently live in `gh-pages/supplemental/` are moved onto the citing paper as `{id}-supp.*` (and `software:` where the extra is a software report) and appear as labelled links on the volume index.
- [ ] Those links resolve to working URLs on proceedings.mlr.press, next to the paper PDF (old-tree `{id}/{id}-supp.pdf` is acceptable for volumes that still publish from `gh-pages`).
- [ ] Broken JMLR W&CP HTML wrappers are not the primary public links.
- [ ] Volumes that never had a `supplemental/` directory are unchanged.
- [ ] [v16#1](https://github.com/mlresearch/v16/issues/1) and [v27#2](https://github.com/mlresearch/v27/issues/2) can be closed once the Active Learning and UTL reports are linked.
- [ ] The same treatment is applied to v3 and v6, which have the same unlinked PDFs.

## Notes (Optional)

This requirement states the outcome. CIP-0005 chooses per-paper `-supp` extras over a new volume-level config field.

Do not block on editor confirmation to restore links to files that are already in the volume repository.

## References

- **Related Tenets**: `data-integrity-over-convenience`, `clean-branch-separation`, `reproducible-auditable-pipeline`
- **External Links**: [v16#1](https://github.com/mlresearch/v16/issues/1), [v27#2](https://github.com/mlresearch/v27/issues/2)

## Progress Updates

### 2026-08-19

Requirement written after triaging the remaining open mlresearch issues. Updated the same day: a v1–v60 probe found the same leftover directory on v3, v6, v7, v16, and v27. Outcome is migration onto `{id}-supp.*`, not a new theme field.

CIP-0005 accepted and moved to In Progress; v16/v27 implementation started.
