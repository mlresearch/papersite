---
id: "2026-08-19_v16-v27-challenge-supp-extras"
title: "Attach v16 and v27 challenge reports as per-paper -supp extras"
status: "Completed"
priority: "High"
created: "2026-08-19"
last_updated: "2026-08-19"
category: "bugs"
related_cips: ["0005"]
owner: "Neil Lawrence"
dependencies: []
tags:
- backlog
- extras
- historical-volumes
- v16
- v27
---

# Task: Attach v16 and v27 challenge reports as per-paper -supp extras

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs.

## Description

[v16#1](https://github.com/mlresearch/v16/issues/1) and [v27#2](https://github.com/mlresearch/v27/issues/2) report that challenge appendices in `gh-pages/supplemental/` are not linked from the proceedings pages. CIP-0005 moves those PDFs onto the overview papers using the modern `{id}-supp.*` extras YAML.

v3, v6, and v7 are the same leftover class but have no open issues; they are a follow-up task.

## Acceptance Criteria

- [x] `Datasets_AL_challenge.pdf` and `Software_AL_challenge.pdf` live beside `guyon11a.pdf` as `guyon11a-supp.pdf` and `guyon11a-software.pdf`.
- [x] `guyon11a` post has `extras` (Supplementary PDF) and `software:` pointing at proceedings.mlr.press URLs in the same style as `pdf:`.
- [x] `datasetsutl12a.pdf` lives beside `silver12a.pdf` as `silver12a-supp.pdf`.
- [x] `silver12a` post has `extras` for that file.
- [x] W&CP HTML indexes stay unlinked.
- [x] [v16#1](https://github.com/mlresearch/v16/issues/1) and [v27#2](https://github.com/mlresearch/v27/issues/2) are closed with the new URLs.

## Implementation Notes

- `git mv` on `gh-pages`; do not commit `_config.yml--`.
- Theme reads YAML only; filenames are for URL consistency with `{id}/{id}.pdf`.
- Do not re-run `create_volume.rb`.

## Related

- CIP: 0005
- GitHub: [v16#1](https://github.com/mlresearch/v16/issues/1), [v27#2](https://github.com/mlresearch/v27/issues/2)

## Progress Updates

### 2026-08-19

Task created as In Progress. CIP-0005 accepted; implementing v16 and v27 first.

Pushed `mlresearch/v16` `5f217f0` and `mlresearch/v27` `c2197ea` to `gh-pages`. Closed [v16#1](https://github.com/mlresearch/v16/issues/1) and [v27#2](https://github.com/mlresearch/v27/issues/2). GitHub Pages may take a few minutes to show the new links.
