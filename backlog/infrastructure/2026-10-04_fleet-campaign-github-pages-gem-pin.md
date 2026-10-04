---
id: "2026-10-04_fleet-campaign-github-pages-gem-pin"
title: "Fleet campaign: pin github-pages >= 228 on volume Gemfiles"
status: "Ready"
priority: "High"
created: "2026-10-04"
last_updated: "2026-10-04"
category: "infrastructure"
related_cips: ["000A"]
owner: "Neil Lawrence"
dependencies: []
tags:
- backlog
- fleet
- campaign
- jekyll
- github-pages
- ruby
---

# Task: Fleet campaign github-pages Gemfile pin (CIP-000A)

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs.

## Description

Roll out `gem 'github-pages', '>= 228'` on published volume `Gemfile`s so
Bundler cannot resolve github-pages **222** / liquid **4.0.3**, which
crashes Jekyll on Ruby 3.2 with `undefined method tainted?`.

**Birth path already closed** (`papersite` `80d062e`:
`MLResearch.write_gemfile`). **Pilot volume fixed directly**
(`mlresearch/v1` `gh-pages` `b52e9aa`). This task is the fleet backfill
for existing repos.

### Scope (local inventory, 2026-10-04)

- ~**305** local `v*` / `r*` clones have a `gh-pages` `Gemfile` with
  unpinned `gem 'github-pages'` (same broken pattern).
- Acute CI failure requires a custom Pages workflow on Ruby 3.2 (v1’s
  `.github/workflows/jekyll.yml`). Most volumes may still use the legacy
  builder today; pin anyway so adopting Actions + Ruby 3.2 does not
  re-break builds.
- Where `.github/workflows/jekyll.yml` sets `bundler-cache: true`, bump
  `cache-version` (or otherwise invalidate) so Actions does not reuse a
  lockfile hashed from the bad resolution.

### Incident reference

See bug `2026-10-04_jekyll-liquid-tainted-ruby32` for full diagnosis
(Bundler prefers `jekyll-include-cache` 0.3.1 → forces github-pages 222).

## Acceptance Criteria

- [ ] Campaign YAML under `fleet/campaigns/` loadable by `pmfleet`
  (or a documented dedicated sync script if file-copy is the wrong tool)
- [ ] Classifier: `match` when Gemfile pins `github-pages` `>= 228` (or
  equivalent); `missing` when unpinned / too low; `skip` when no Gemfile
  on target branch
- [ ] Target branch: `gh-pages` (or `gh-pages-if-posts` / explicit policy
  that reaches the Jekyll `Gemfile`)
- [ ] Pilot: small cohort via `pmfleet apply --open-prs --limit N` (or
  script dry-run → limited push); v1 already done and should classify
  `match`
- [ ] Bulk apply until `missing` is empty or accounted as skip/custom
- [ ] No force-push to `main` / `gh-pages`; custom Gemfiles left alone
  unless strategy documented
- [ ] Optional: bump `cache-version` in volume `jekyll.yml` when present
- [ ] `fleet/README.md` birth-path note that new Gemfiles come from
  pinned `write_gemfile` (already true after `80d062e`)

## Implementation Notes

### Preferred approach

`pmfleet` today copies whole papersite-owned files. A full Gemfile
replace is risky: some volumes omit `webrick`, some differ slightly.
Prefer one of:

1. **Surgical campaign / script** — replace the
   `gem 'github-pages'` line with `gem 'github-pages', '>= 228'` (and
   leave comments/other gems alone); open PR on `gh-pages`.
2. **Canonical Gemfile template** in papersite — only if inventory shows
   Gemfiles are uniform enough to overwrite safely.

If extending `pmfleet` for in-place edits, keep CIP-000A invariants:
inventory/plan/status read-only; apply requires `--open-prs`; never
force-push protected branches.

### Suggested campaign sketch

```yaml
id: github-pages-gem-pin
title: "Pin github-pages >= 228 on volume Gemfiles (Ruby 3.2 / liquid)"
related_cips: ["000A"]
target_branch: gh-pages
classify:
  match_markers:
    - "github-pages"
    - ">= 228"
  # treat unpinned github-pages as missing (needs custom classifier
  # or post-filter: has github-pages but not >= 228)
  require_published: true
pr:
  branch: chore/fleet-github-pages-gem-pin
  title: "Pin github-pages >= 228 for Ruby 3.2 Jekyll builds"
```

Classifier may need a small `pmfleet` enhancement (match only if pin
present; missing if `github-pages` without pin) rather than naive
substring markers alone.

### Verification

On a patched clone:

```bash
bundle lock
grep -E 'github-pages \(|liquid \(' Gemfile.lock
# expect github-pages (>= 228) → 232 and liquid 4.0.4
```

CI: Pages workflow `jekyll build` should no longer raise `tainted?`.

### Out of scope

- Upgrading all volumes to a custom Actions Pages workflow
- Changing Ruby version pins (3.2.2 is fine once liquid >= 4.0.4)
- Letter-batched deploy / PDF moves (CIP-0007)

## Related

- Bug: `2026-10-04_jekyll-liquid-tainted-ruby32`
- CIP: 000A (fleet mechanism)
- Birth path: `lib/mlresearch.rb` `write_gemfile`
- Sibling campaigns: `pmlint-posts-ci`, `pr-template-gh-pages`
- Commits already landed: `papersite@80d062e`, `v1@b52e9aa`

## Progress Updates

### 2026-10-04

Task created after v1 Pages failure and generator fix. Local scan:
305 clones still unpinned on `gh-pages` Gemfile. Status → Ready
(pmfleet apply exists; campaign YAML / surgical edit path still to do).
