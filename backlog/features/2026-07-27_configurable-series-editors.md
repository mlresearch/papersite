---
id: "2026-07-27_configurable-series-editors"
title: "Configurable series editors via YAML data file"
status: "Completed"
priority: "Medium"
created: "2026-07-27"
last_updated: "2026-07-27"
owner: ""
dependencies: []
---

# Task: Configurable series editors via YAML data file

## Description

Series editors for PMLR were hardcoded in three Ruby library files
(`mlresearch.rb`, `update_config.rb`, `bibtex2yaml.rb`), with date or
volume-number guards copied inconsistently across each file. This task
replaces all hardcoded logic with a single `series_editors.yml` data file at
the project root, and a shared `MLResearch.series_editors_for_date(date)`
helper method.

## Acceptance Criteria

- `series_editors.yml` exists at the project root listing all editors with
  `given`, `family`, `start` (and optional `end`) date fields.
- `MLResearch.series_editors_for_date(date)` returns the editors active on the
  given publication date.
- `mlresearch.rb`, `update_config.rb`, and `bibtex2yaml.rb` all use the helper
  instead of hardcoded names and date guards.
- Adding or removing a series editor requires only an edit to `series_editors.yml`.

## Implementation Notes

- `bibtex2yaml.rb` previously used volume-number guards rather than dates;
  this is now harmonised to use publication date via `ha['published']`.
- The file path is resolved relative to `mlresearch.rb` using `__FILE__`.

## Related

- None

## Progress Updates

### 2026-07-27
Implemented. Added Hoel Kervadec and Tegan Emerson as series editors from
2026-07-01.
