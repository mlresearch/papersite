---
id: "2026-10-04_jekyll-liquid-tainted-ruby32"
title: "Jekyll Pages build fails on Ruby 3.2: liquid 4.0.3 undefined method tainted?"
status: "Completed"
priority: "High"
created: "2026-10-04"
last_updated: "2026-10-04"
category: "bugs"
related_cips: []
owner: "Neil Lawrence"
dependencies: []
tags:
- backlog
- bugs
- jekyll
- github-pages
- ruby
- liquid
---

# Task: Jekyll Pages build fails on Ruby 3.2 (`tainted?`)

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs. Don't link directly to requirements (bottom-up pattern).

## Description

`mlresearch/v1` GitHub Pages deploy (`Deploy Jekyll site to Pages` on
`gh-pages`) failed during `bundle exec jekyll build` with:

```
Liquid Exception: undefined method `tainted?' for
"Gaussian Process Approximations of Stochastic Differential Equations":String
in /_layouts/inproceedings.html
```

Stack points at `liquid-4.0.3` (`Liquid::Variable#taint_check`). Ruby 3.2
removed `Object#tainted?`; Liquid 4.0.4 fixed that API use.

### Root cause

Volume `Gemfile` pattern (from `MLResearch.write_gemfile`):

```ruby
gem 'jekyll'
group :jekyll_plugins do
  gem 'github-pages'
  gem 'jekyll-remote-theme'
  gem 'jekyll-include-cache'
end
```

Unpinned `jekyll-include-cache` prefers **0.3.1**. `github-pages >= 223`
pins `jekyll-include-cache = 0.2.1`, so Bundler walks `github-pages` back
to **222** (which does not constrain include-cache) and thus **liquid
4.0.3**. Workflow uses `ruby-version: '3.2.2'` → crash.

Pinning `gem 'github-pages', '>= 228'` resolves to github-pages 232 /
liquid 4.0.4.

### Acute fix (done)

- `mlresearch/v1` `gh-pages` `b52e9aa`: pin + bump Actions `cache-version`
- `papersite` `main` `80d062e`: `write_gemfile` emits the pin for new volumes

Fleet backfill for existing volume Gemfiles is tracked separately.

## Acceptance Criteria

- [x] Diagnose `tainted?` failure on v1 Pages build
- [x] Fix v1 `Gemfile` / workflow cache and push `gh-pages`
- [x] Fix papersite `write_gemfile` birth path so new volumes do not regress
- [x] Record fleet backfill task for remaining volumes

## Implementation Notes

Volumes that still use GitHub’s legacy Pages builder (no custom Ruby 3.2
workflow) may not fail today; any volume that adopts the Actions + Ruby
3.2 path will hit this until the Gemfile is pinned.

## Related

- Fleet backfill: `2026-10-04_fleet-campaign-github-pages-gem-pin`
- Commits: `mlresearch/v1@b52e9aa`, `mlresearch/papersite@80d062e`
- Liquid fix: Shopify/liquid 4.0.4; github-pages >= 228

## Progress Updates

### 2026-10-04

v1 Pages build log diagnosed; pin verified via `bundle lock` (232 /
liquid 4.0.4). v1 and papersite generator fixed and pushed. Status →
Completed; fleet gap tracked in infrastructure task.
