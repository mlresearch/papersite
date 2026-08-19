---
id: "2026-08-19_v3-v6-v7-challenge-supp-extras"
title: "Attach remaining W&CP supplemental PDFs (v3, v6, v7 cleanup)"
status: "Ready"
priority: "Medium"
created: "2026-08-19"
last_updated: "2026-08-19"
category: "bugs"
related_cips: ["0005"]
owner: "Neil Lawrence"
dependencies:
- "2026-08-19_v16-v27-challenge-supp-extras"
tags:
- backlog
- extras
- historical-volumes
---

# Task: Attach remaining W&CP supplemental PDFs (v3, v6, v7 cleanup)

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs.

## Description

Same leftover `gh-pages/supplemental/` pattern as v16/v27, with no open GitHub issues.

- v3: three PDFs on `guyon08a` (`-supp`, `-software`, `-supp-factsheets`).
- v6: nine team fact sheets on `guyon10a` as `-supp-fsN` extras.
- v7: HTML only; drop dead `supplementalurl` and the empty Supplemental section.

Do this after v16/v27 are live.

## Acceptance Criteria

- [ ] v3 `guyon08a` extras/software match CIP-0005 file mapping.
- [ ] v6 `guyon10a` lists all nine fact sheets as extras.
- [ ] v7 no longer advertises `supplementalurl` or an empty Supplemental heading.
- [ ] HTML indexes remain unlinked.

## Implementation Notes

Follow CIP-0005. `git mv` on `gh-pages`; extras YAML in the same `{label, link}` shape as v16/v27.

## Related

- CIP: 0005
- Depends on: 2026-08-19_v16-v27-challenge-supp-extras

## Progress Updates

### 2026-08-19

Task created as Ready, blocked on v16/v27 going out first.
