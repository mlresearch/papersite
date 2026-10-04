# Fleet campaigns (CIP-000A)

Papersite-owned artifacts are rolled out to `mlresearch/v*` / `r*` volume
repositories with `bin/pmfleet`. Campaigns are YAML files under
`fleet/campaigns/`.

## Commands

```bash
# Classify local clones (no network, no mutation)
bin/pmfleet inventory --campaign pmlint-posts-ci --clones-dir ~/mlresearch

# Same, single repo or fixture
bin/pmfleet inventory --campaign pmlint-posts-ci --repo tests/fixtures/fleet/v99001

# Dry-run actions for missing repos
bin/pmfleet plan --campaign pmlint-posts-ci --clones-dir ~/mlresearch --format json
```

`inventory` and `plan` are read-only. `apply --open-prs` is a separate
backlog task and is not implemented yet.

## Campaign YAML schema

| Field | Meaning |
|---|---|
| `id` | Campaign id (filename stem should match) |
| `title` | Human title |
| `related_cips` / `related_requirements` | Traceability |
| `source[]` | `papersite:` path relative to papersite root → `dest:` path in volume |
| `target_branch` | `default` \| `gh-pages-if-posts` \| explicit branch name |
| `classify.match_markers` | Dest file must contain each string → `match` |
| `classify.custom_regexes` | Other workflow files matching → `custom` |
| `classify.require_published` | Skip unless `_posts/` or `gh-pages` ref exists |
| `classify.require_unpublished` | Skip if volume looks published |
| `classify.skip_if_missing_paths` | Skip if none of these paths exist |
| `pr.branch` / `pr.title` | Used by future `apply` |

Classifiers: `missing` \| `match` \| `custom` \| `skip`.

## Boundary

`pmfleet` installs files via PR. It does **not** letter-batch deploy PDFs or
posts ([CIP-0007](../cip/cip0007.md)).
