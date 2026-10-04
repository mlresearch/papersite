---
id: "2026-10-04_fleet-new-volume-templates"
title: "Wire create_volume / templates so new volumes ship fleet artifacts"
status: "Completed"
priority: "Medium"
created: "2026-10-04"
last_updated: "2026-10-04"
category: "features"
related_cips: ["000A", "0008", "0009"]
owner: "Neil Lawrence"
dependencies: []
tags:
- backlog
- fleet
- create-volume
- templates
---

# Task: New-volume fleet templates (CIP-000A)

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs.

## Description

Close the “born without the artifact” hole: update `create_volume` and/or
checked-in volume templates so **new** unpublished volumes get the intake
`pmlint` workflow, and the path that creates published-site scaffolding
gets the posts workflow (or a clear documented install step).

Steady-state close-out for the first two campaigns; can start before bulk
fleet apply finishes.

## Acceptance Criteria

- [x] New unpublished volume from current tooling includes intake workflow
      (or documented equivalent)
- [x] Published-volume scaffolding path includes posts workflow when
      applicable
- [x] Source-of-truth note: papersite owns the canonical file; volumes hold
      a copy/thin wrapper
- [x] Does not re-open CIP-0007 deploy behaviour

## Implementation Notes

Prefer copying from the same example workflow files campaigns use, so
fleet and birth path do not drift.

## Related

- CIP: 000A
- Campaigns: posts + intake backlog tasks

## Progress Updates

### 2026-10-04

Task created as Ready when CIP-000A was Accepted.

### 2026-10-04

Added `bin/install_volume_workflows.sh`; `create_volume.rb` installs intake;
`deploy_volume.sh` installs posts on `gh-pages`. Documented in `fleet/README.md`.
