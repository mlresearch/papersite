---
id: "2026-10-04_pmfleet-inventory-plan"
title: "Implement pmfleet inventory and plan (read-only fleet classify)"
status: "Completed"
priority: "High"
created: "2026-10-04"
last_updated: "2026-10-04"
category: "features"
related_cips: ["000A"]
owner: "Neil Lawrence"
dependencies: []
tags:
- backlog
- fleet
- pmfleet
---

# Task: pmfleet inventory / plan (CIP-000A)

> **Note**: Backlog tasks are DOING the work defined in CIPs (HOW).
> Use `related_cips` to link to CIPs.

## Description

Add a papersite fleet entrypoint (`bin/pmfleet` or equivalent) with
read-only subcommands:

- `inventory --campaign <id>` — classify each volume repo as
  `missing` / `match` / `custom` / `skip`
- `plan --campaign <id>` — dry-run of intended actions (no git mutation,
  no PRs)

Support local clone sets and remote discovery via `gh` as designed in
CIP-000A. Load campaign YAML from `fleet/campaigns/<id>.yml` (schema may
land in parallel docs task; tool should tolerate the sketch in the CIP).

## Acceptance Criteria

- [x] `inventory` and `plan` default to read-only (no pushes, no PRs)
- [x] Per-repo classifier labels emitted in a machine-readable report
- [x] Works against a fixture/local clone set without network
- [x] Documented invocation in tool `--help` or short README pointer

## Implementation Notes

Do not implement `apply` here. Do not touch volume content branches for
publish (CIP-0007 boundary). Name is flexible (`pmfleet` preferred).

## Related

- CIP: 000A
- Next: `2026-10-04_pmfleet-apply-status`
- Schema/docs: `2026-10-04_fleet-campaign-schema-docs`

## Progress Updates

### 2026-10-04

Task created as Ready when CIP-000A was Accepted.

### 2026-10-04

Implemented `bin/pmfleet` + `lib/pmfleet.py` with `inventory` / `plan`,
campaign YAML load, fixture suite (`tests/python/test_pmfleet.py`).
`apply` still stubs exit 2.
