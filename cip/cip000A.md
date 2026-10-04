---
author: "Neil D. Lawrence"
created: "2026-10-04"
id: "000A"
last_updated: "2026-10-04"
status: "Proposed"
compressed: false
related_requirements: []
related_cips: ["0004", "0007", "0008", "0009"]
tags:
- cip
- fleet
- rollout
- volumes
- github
- automation
- multi-repo
title: "Fleet rollout — distribute papersite changes across volume repositories"
---

# CIP-000A: Fleet rollout — distribute papersite changes across volume repositories

> **Note**: CIPs describe HOW to achieve requirements (WHAT).
> This CIP defines a **reusable** process and tooling shape for pushing
> papersite-owned artifacts (workflows, templates, scripts, config) into
> many existing `mlresearch/vNNN` / `rNNN` repos. Individual campaigns
> (e.g. enable `pmlint posts` CI) reference this CIP rather than
> inventing one-off bulk-update procedures.

## Status

- [x] Proposed - Initial idea documented
- [ ] Accepted - Approved, ready to start work
- [ ] In Progress - Actively being implemented
- [ ] Implemented - Work complete, awaiting verification
- [ ] Closed - Verified and complete
- [ ] Rejected - Will not be implemented
- [ ] Deferred - Postponed

## Summary

Papersite is the source of shared tooling; volume repositories are the
fleet. Whenever we ship something that must exist *inside* each volume
repo (GitHub Actions workflow, PR template, hook, README fragment, …),
we need the same operational pattern:

1. **Inventory** the fleet (who already has it, who customised it, who
   is skipped)
2. **Dry-run** a planned change set
3. **Pilot** on a small cohort via pull requests
4. **Bulk open PRs** (explicit flag; no silent force-push)
5. **Close the gap at birth** so new volumes get the artifact from
   `create_volume` / templates and do not re-open the hole

This CIP designs that pattern once. **Campaigns** are concrete rollouts
that reuse it. The first campaign is enabling CIP-0008 / CIP-0009
`pmlint` workflows (finishing the fleet half of REQ-0005). Later
campaigns will repeat the same machinery (further CIP-0004 CI pieces,
shared templates, policy files, …).

## Motivation

We have already hit the gap twice in spirit:

- Example workflows live under papersite; existing volumes never see them
  unless someone copies by hand
- Data fixes can ship on feature branches (`fix/posts-yaml-lint`), but
  that does not install ongoing gates
- The next CI/CD or template improvement will face the same hundreds of
  repos

One-off shell loops do not encode skip rules, dry-run, rate limits, or
“do not clobber custom CI.” A durable fleet tool + written campaign
checklist does. Aligns with `automation-with-guardrails` and
`reproducible-auditable-pipeline`.

## Detailed Description

### Concepts

| Term | Meaning |
|---|---|
| **Fleet** | Active `mlresearch/v*` and `r*` repositories (plus local clone set when offline) |
| **Artifact** | File(s) or snippet owned by papersite that should appear in volume repos |
| **Campaign** | One named rollout of one artifact (or small coherent set), with its own success criteria and links to the CIP/REQ that motivated it |
| **Classifier** | Per-repo label: `missing` / `match` / `custom` / `skip` relative to the campaign’s desired state |

### Fleet tool (papersite-owned)

Add a papersite entrypoint (name flexible, e.g. `bin/pmfleet` or
`scripts/fleet_rollout.py`) with subcommands shared by all campaigns:

```text
pmfleet inventory --campaign <id>     # read-only classify → report
pmfleet plan      --campaign <id>     # dry-run: repos × actions
pmfleet apply     --campaign <id> --open-prs   # explicit mutation
pmfleet status    --campaign <id>     # progress vs inventory
```

**Invariants (every campaign):**

- Default is read-only (`inventory` / `plan`); `apply` requires
  `--open-prs` (or equally explicit flag)
- Changes land via **branch + PR**, never `push --force` to `main` /
  `gh-pages`
- Rate-limit PR creation; resume-safe (re-run skips repos already PR’d
  or merged)
- `custom` repos are reported, not overwritten, unless the campaign
  document explicitly defines a merge strategy
- Campaign config lives in papersite (e.g. `fleet/campaigns/<id>.yml`)
  describing desired paths, source files, target branch policy, and
  classifiers

### Campaign config (sketch)

```yaml
id: pmlint-posts-ci
title: "Install pmlint posts workflow on published volumes"
related_cips: ["0009", "000A"]
related_requirements: ["0005"]
source:
  - papersite: .github/workflows/pmlint-posts-volume-example.yml
    dest: .github/workflows/pmlint-posts.yml
target_branch: auto   # policy: published → branch that runs Actions for _posts; else default
classify:
  match_if: "workflow file contains marker 'pmlint-posts' and path filter _posts"
  skip_if: ["archived", "no-actions"]
  custom_if: "other workflow mentions check_posts|pmlint posts"
pilot:
  published: 5
  unpublished: 0
pr:
  branch: chore/fleet-pmlint-posts-ci
  title: "Install pmlint posts CI (CIP-000A / CIP-0009)"
```

A second campaign YAML covers intake `pmlint` for unpublished volumes.
Same tool, different config.

### Target branch policy

Campaigns declare how to choose the PR base:

- **default** — repo default branch
- **gh-pages-if-posts** — if `_posts` live on `gh-pages`, open against
  that branch (common for published volumes)
- **explicit** — campaign pins a branch name

Wrong branch = workflow never runs. Encode detection in inventory.

### Steady state (stop the bleeding)

Fleet apply alone is insufficient. Each campaign’s close-out includes:

1. Update **new-volume** path (`create_volume`, cookiecutter, or checked-in
   template) so new repos are born with the artifact
2. Document “source of truth = papersite file X; volumes hold a copy /
   thin wrapper”

Future CIP work that introduces volume-local files should **require** a
campaign id (or an explicit “no fleet needed” rationale) before Closed.

### First campaigns (not the whole CIP)

| Campaign id | Artifact | Motivating CIP / REQ |
|---|---|---|
| `pmlint-posts-ci` | posts workflow example → volume | CIP-0009 / REQ-0005 |
| `pmlint-intake-ci` | intake workflow example → volume | CIP-0008 / CIP-0004 phase 1 |

Further campaigns (PR templates, deploy helpers, compile workflows from
CIP-0004, …) are new YAML + backlog tasks under this CIP’s tool, or
thin child CIPs that only describe the artifact if design is non-trivial.

### Out of scope

- Designing the linters themselves (0008 / 0009)
- Batched large-volume deploy mechanics ([CIP-0007](cip0007.md)) — though
  a future campaign might distribute a deploy wrapper
- Auto-merge of fleet PRs
- Changing org-level GitHub Actions permissions

## Implementation Plan

1. **Accept** general fleet model (tool + campaign config + PR-only apply).
2. **Implement** `inventory` / `plan` against local clones + `gh` remotes.
3. **Implement** `apply --open-prs` with rate limit and resume.
4. **Land campaign configs** for `pmlint-posts-ci` and `pmlint-intake-ci`.
5. **Pilot** each campaign; fix classifiers / branch policy.
6. **Bulk apply**; track `status` until `missing` is empty or skipped.
7. **Wire create_volume / templates** for both workflows.
8. **Document** how to add the next campaign (checklist in README or
   `fleet/README.md`).
9. **Keep CIP-000A open** as the home for the tool; mark campaigns
   complete in their YAML / backlog rather than closing 000A after the
   first rollout — *or* close 000A when the tool is stable and treat
   later campaigns as backlog-only. **Prefer:** close 000A when tool +
   docs + first two campaigns are done; later campaigns are backlog
   tasks linking `related_cips: ["000A"]`.

## Backward Compatibility

- No volume content format changes from the tool itself
- Campaigns must state content impact (workflows are additive)
- Custom repos remain untouched by default

## Testing Strategy

- Unit tests for classifiers on fixture repo layouts
- `plan` against a recorded inventory snapshot (no network)
- Integration: apply to a throwaway org repo or local bare remotes
- Pilot campaigns on real volumes before bulk

## Related Requirements

Campaigns link to the REQ they serve. This CIP itself may later gain a
dedicated requirement (“volume fleet updates are inventory-driven and
PR-based”); until then campaigns carry `related_requirements`.

First campaigns touch [REQ-0005](../requirements/req0005_post-yaml-edits-validated.md).

## Implementation Status

- [x] CIP Proposed as **general** fleet mechanism (not pmlint-only)
- [ ] Accepted after review
- [ ] Fleet tool (`inventory` / `plan` / `apply` / `status`)
- [ ] Campaign config schema + `fleet/` (or equivalent) docs
- [ ] Campaign `pmlint-posts-ci` complete
- [ ] Campaign `pmlint-intake-ci` complete
- [ ] New-volume templates updated
- [ ] Checklist for “next campaign”
- [ ] CIP Closed (tool stable; further campaigns via backlog)

## References

- Motivating instances: [CIP-0008](cip0008.md), [CIP-0009](cip0009.md)
- Umbrella CI/CD: [CIP-0004](cip0004.md)
- Example workflow sources under papersite `.github/workflows/`
- Tenets: `automation-with-guardrails`, `reproducible-auditable-pipeline`
