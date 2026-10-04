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

# PR progress (classification + gh pr state for campaign head branch)
bin/pmfleet status --campaign pmlint-posts-ci --clones-dir ~/mlresearch

# Open PRs (explicit flag required; never force-pushes main/gh-pages)
bin/pmfleet apply --campaign pmlint-posts-ci --clones-dir ~/mlresearch \
  --open-prs --limit 5 --rate-limit 2
```

`inventory`, `plan`, and `status` are read-only. `apply` refuses to run
without `--open-prs`. Re-runs skip repos that already have an open or
merged PR on the campaign head branch.

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

## Birth path (stop the bleeding)

| When | Installs | How |
|---|---|---|
| `proceedings-template` | both workflows | kept in sync with papersite examples (`vNNN`/`rNNN` **or** `proceedings-template`) |
| `create_volume.rb` (unpublished) | intake `pmlint.yml` | `bin/install_volume_workflows.sh intake` |
| `deploy_volume.sh` → `gh-pages` | posts `pmlint-posts.yml` | `bin/install_volume_workflows.sh posts` |

On the template, intake runs for initial BibTeX/PDF PRs; posts is path-filtered to `_posts/**` so it stays quiet until corrections exist.

Canonical sources stay under papersite `.github/workflows/*-example.yml`.
Volumes hold copies; fleet campaigns close the gap for existing repos.

## Adding the next campaign

1. Add `fleet/campaigns/<id>.yml` (see schema above).
2. Point `source[]` at papersite-owned files (do not fork copies in the YAML).
3. Add classifier fixtures under `tests/fixtures/fleet/v9900x` if needed; extend
   `tests/python/test_pmfleet.py`.
4. `pmfleet inventory` / `plan` on a local clones dir.
5. Pilot: `pmfleet apply --open-prs --limit 5`.
6. Bulk: raise/omit `--limit`; track with `pmfleet status`.
7. Update birth path (`install_volume_workflows.sh` / create_volume / deploy)
   so new volumes do not re-open the hole.
8. Backlog task with `related_cips: ["000A"]` (and the motivating CIP/REQ).

If a CIP adds volume-local files but fleet is unnecessary, document that
rationale in the CIP before Closed.

## Boundary

`pmfleet` installs files via PR. It does **not** letter-batch deploy PDFs or
posts ([CIP-0007](../cip/cip0007.md)).
