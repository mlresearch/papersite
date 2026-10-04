#!/usr/bin/env python3
"""pmfleet — inventory / plan fleet artifact rollouts (CIP-000A).

Read-only by default. apply --open-prs is intentionally not implemented yet.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Any, Iterable, List, Optional, Sequence

try:
    import yaml
except ImportError as exc:  # pragma: no cover
    raise SystemExit(
        "pmfleet requires PyYAML. Install with:\n"
        "  python3 -m pip install -r tests/python/requirements.txt"
    ) from exc


VOLUME_NAME_RE = re.compile(r"^[vr]\d+$")


@dataclass
class SourceMapping:
    papersite: str
    dest: str


@dataclass
class Campaign:
    id: str
    title: str
    source: List[SourceMapping]
    target_branch: str = "default"
    related_cips: List[str] = field(default_factory=list)
    related_requirements: List[str] = field(default_factory=list)
    match_markers: List[str] = field(default_factory=list)
    custom_regexes: List[str] = field(default_factory=list)
    require_published: bool = False
    require_unpublished: bool = False
    skip_if_missing_paths: List[str] = field(default_factory=list)
    pr_branch: str = ""
    pr_title: str = ""
    path: Optional[Path] = None

    @classmethod
    def load(cls, path: Path) -> "Campaign":
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            raise ValueError(f"Campaign YAML must be a mapping: {path}")
        cid = str(data.get("id") or path.stem)
        source_raw = data.get("source") or []
        source = [
            SourceMapping(papersite=str(item["papersite"]), dest=str(item["dest"]))
            for item in source_raw
        ]
        if not source:
            raise ValueError(f"Campaign {cid} has empty source[]")
        classify = data.get("classify") or {}
        pr = data.get("pr") or {}
        return cls(
            id=cid,
            title=str(data.get("title") or cid),
            source=source,
            target_branch=str(data.get("target_branch") or "default"),
            related_cips=[str(x) for x in (data.get("related_cips") or [])],
            related_requirements=[
                str(x) for x in (data.get("related_requirements") or [])
            ],
            match_markers=[str(x) for x in (classify.get("match_markers") or [])],
            custom_regexes=[str(x) for x in (classify.get("custom_regexes") or [])],
            require_published=bool(classify.get("require_published", False)),
            require_unpublished=bool(classify.get("require_unpublished", False)),
            skip_if_missing_paths=[
                str(x) for x in (classify.get("skip_if_missing_paths") or [])
            ],
            pr_branch=str(pr.get("branch") or f"chore/fleet-{cid}"),
            pr_title=str(pr.get("title") or f"Fleet campaign {cid}"),
            path=path,
        )


@dataclass
class RepoResult:
    name: str
    path: str
    classification: str
    reason: str
    target_branch: str
    actions: List[dict] = field(default_factory=list)


def papersite_root_from_argv_env(explicit: Optional[str] = None) -> Path:
    if explicit:
        return Path(explicit).resolve()
    env = os.environ.get("PAPERSITE_ROOT")
    if env:
        return Path(env).resolve()
    # lib/pmfleet.py → parents[1] is papersite root
    return Path(__file__).resolve().parents[1]


def campaign_path(root: Path, campaign_id: str) -> Path:
    path = root / "fleet" / "campaigns" / f"{campaign_id}.yml"
    if not path.is_file():
        raise FileNotFoundError(f"Campaign not found: {path}")
    return path


def discover_repos(clones_dir: Optional[Path], repos: Sequence[Path]) -> List[Path]:
    found: List[Path] = []
    for repo in repos:
        p = repo.resolve()
        if not p.is_dir():
            raise FileNotFoundError(f"Repo path is not a directory: {p}")
        found.append(p)
    if clones_dir is not None:
        base = clones_dir.resolve()
        if not base.is_dir():
            raise FileNotFoundError(f"Clones dir not found: {base}")
        for child in sorted(base.iterdir()):
            if child.is_dir() and VOLUME_NAME_RE.match(child.name):
                found.append(child.resolve())
    # de-dupe preserving order
    seen = set()
    out: List[Path] = []
    for p in found:
        if p not in seen:
            seen.add(p)
            out.append(p)
    return out


def looks_published(repo: Path) -> bool:
    if (repo / "_posts").is_dir():
        return True
    git_dir = repo / ".git"
    # Loose check: packed-refs or refs/heads/gh-pages, or worktree file
    if (repo / ".git").is_file() or git_dir.is_dir():
        candidates = [
            repo / ".git" / "refs" / "heads" / "gh-pages",
            repo / ".git" / "refs" / "remotes" / "origin" / "gh-pages",
        ]
        for c in candidates:
            if c.is_file():
                return True
        packed = repo / ".git" / "packed-refs"
        if packed.is_file():
            text = packed.read_text(encoding="utf-8", errors="replace")
            if re.search(r"refs/(heads|remotes/origin)/gh-pages\b", text):
                return True
    # Marker used by fixtures without a real git dir
    if (repo / ".pmfleet-published").is_file():
        return True
    return False


def resolve_target_branch(campaign: Campaign, repo: Path) -> str:
    policy = campaign.target_branch
    if policy == "default":
        return "default"
    if policy == "gh-pages-if-posts":
        if (repo / "_posts").is_dir() or looks_published(repo):
            return "gh-pages"
        return "default"
    return policy


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def workflow_files(repo: Path) -> List[Path]:
    wf = repo / ".github" / "workflows"
    if not wf.is_dir():
        return []
    return sorted(
        [
            p
            for p in wf.iterdir()
            if p.is_file() and p.suffix in {".yml", ".yaml"}
        ]
    )


def classify_repo(campaign: Campaign, repo: Path, papersite: Path) -> RepoResult:
    name = repo.name
    target = resolve_target_branch(campaign, repo)
    published = looks_published(repo)

    if campaign.skip_if_missing_paths:
        if not any((repo / rel).exists() for rel in campaign.skip_if_missing_paths):
            return RepoResult(
                name=name,
                path=str(repo),
                classification="skip",
                reason="skip_if_missing_paths: none present",
                target_branch=target,
            )

    if campaign.require_published and not published:
        return RepoResult(
            name=name,
            path=str(repo),
            classification="skip",
            reason="require_published: volume does not look published",
            target_branch=target,
        )

    if campaign.require_unpublished and published:
        return RepoResult(
            name=name,
            path=str(repo),
            classification="skip",
            reason="require_unpublished: volume looks published",
            target_branch=target,
        )

    # Verify papersite sources exist (campaign validity)
    for mapping in campaign.source:
        src = papersite / mapping.papersite
        if not src.is_file():
            return RepoResult(
                name=name,
                path=str(repo),
                classification="skip",
                reason=f"papersite source missing: {mapping.papersite}",
                target_branch=target,
            )

    dest_paths = [repo / m.dest for m in campaign.source]
    primary = dest_paths[0]
    dest_texts = []
    all_dest_present = True
    for dp in dest_paths:
        if dp.is_file():
            dest_texts.append(read_text(dp))
        else:
            all_dest_present = False

    if all_dest_present and campaign.match_markers:
        combined = "\n".join(dest_texts)
        if all(marker in combined for marker in campaign.match_markers):
            return RepoResult(
                name=name,
                path=str(repo),
                classification="match",
                reason=f"dest contains match_markers ({primary.relative_to(repo)})",
                target_branch=target,
            )

    # custom: other workflows match custom_regexes, and dest is absent or unmatched
    if campaign.custom_regexes:
        patterns = [re.compile(rx, re.I) for rx in campaign.custom_regexes]
        for wf in workflow_files(repo):
            # Ignore exact dest paths we manage
            if any(wf.resolve() == dp.resolve() for dp in dest_paths if dp.exists()):
                continue
            text = read_text(wf)
            if any(p.search(text) for p in patterns):
                return RepoResult(
                    name=name,
                    path=str(repo),
                    classification="custom",
                    reason=f"workflow {wf.relative_to(repo)} matches custom_regexes",
                    target_branch=target,
                )

    if all_dest_present and not campaign.match_markers:
        return RepoResult(
            name=name,
            path=str(repo),
            classification="match",
            reason="dest file(s) present",
            target_branch=target,
        )

    actions = [
        {
            "action": "open_pr",
            "branch": campaign.pr_branch,
            "title": campaign.pr_title,
            "base": target,
            "files": [
                {"from": m.papersite, "to": m.dest} for m in campaign.source
            ],
        }
    ]
    reason = "dest missing or markers not matched"
    if primary.is_file():
        reason = "dest present but match_markers not satisfied"
    return RepoResult(
        name=name,
        path=str(repo),
        classification="missing",
        reason=reason,
        target_branch=target,
        actions=actions,
    )


def build_plan(results: Iterable[RepoResult]) -> List[dict]:
    plan = []
    for r in results:
        if r.classification == "missing":
            plan.append(
                {
                    "repo": r.name,
                    "path": r.path,
                    "classification": r.classification,
                    "actions": r.actions,
                }
            )
    return plan


def print_table(results: Sequence[RepoResult]) -> None:
    counts = {"missing": 0, "match": 0, "custom": 0, "skip": 0}
    for r in results:
        counts[r.classification] = counts.get(r.classification, 0) + 1
    print(
        f"{'REPO':<12} {'CLASS':<10} {'BASE':<16} REASON"
    )
    print("-" * 72)
    for r in results:
        print(f"{r.name:<12} {r.classification:<10} {r.target_branch:<16} {r.reason}")
    print("-" * 72)
    print(
        "totals: "
        + ", ".join(f"{k}={v}" for k, v in counts.items() if v or k in counts)
    )


def cmd_inventory(args: argparse.Namespace) -> int:
    root = papersite_root_from_argv_env(args.papersite_root)
    campaign = Campaign.load(campaign_path(root, args.campaign))
    repos = discover_repos(
        Path(args.clones_dir) if args.clones_dir else None,
        [Path(p) for p in (args.repo or [])],
    )
    if not repos:
        print(
            "ERROR: No volume repos found. Pass --repo and/or --clones-dir "
            "containing vNNN/rNNN directories.",
            file=sys.stderr,
        )
        return 1
    results = [classify_repo(campaign, repo, root) for repo in repos]
    payload = {
        "campaign": campaign.id,
        "papersite_root": str(root),
        "read_only": True,
        "repos": [asdict(r) for r in results],
    }
    if args.format == "json":
        print(json.dumps(payload, indent=2, sort_keys=True))
    else:
        print(f"campaign: {campaign.id} ({campaign.title})")
        print(f"papersite: {root}")
        print_table(results)
    return 0


def cmd_plan(args: argparse.Namespace) -> int:
    root = papersite_root_from_argv_env(args.papersite_root)
    campaign = Campaign.load(campaign_path(root, args.campaign))
    repos = discover_repos(
        Path(args.clones_dir) if args.clones_dir else None,
        [Path(p) for p in (args.repo or [])],
    )
    if not repos:
        print(
            "ERROR: No volume repos found. Pass --repo and/or --clones-dir.",
            file=sys.stderr,
        )
        return 1
    results = [classify_repo(campaign, repo, root) for repo in repos]
    plan = build_plan(results)
    payload = {
        "campaign": campaign.id,
        "papersite_root": str(root),
        "read_only": True,
        "would_mutate": False,
        "planned": plan,
        "skipped": [
            asdict(r)
            for r in results
            if r.classification != "missing"
        ],
    }
    if args.format == "json":
        print(json.dumps(payload, indent=2, sort_keys=True))
    else:
        print(f"plan campaign={campaign.id} (dry-run, no git writes)")
        if not plan:
            print("No open_pr actions (no missing repos).")
        for item in plan:
            print(f"- {item['repo']}: open_pr base={item['actions'][0]['base']}")
            for f in item["actions"][0]["files"]:
                print(f"    {f['from']} -> {f['to']}")
        print(
            f"summary: planned={len(plan)} "
            f"other={len(results) - len(plan)}"
        )
    return 0


def cmd_apply(_args: argparse.Namespace) -> int:
    print(
        "ERROR: apply is not implemented yet "
        "(see backlog 2026-10-04_pmfleet-apply-status).",
        file=sys.stderr,
    )
    return 2


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="pmfleet",
        description=(
            "Fleet rollout helper (CIP-000A). "
            "inventory/plan are read-only classifiers for volume repos."
        ),
    )
    sub = p.add_subparsers(dest="command", required=True)

    def add_common(sp: argparse.ArgumentParser) -> None:
        sp.add_argument(
            "--campaign",
            required=True,
            help="Campaign id (fleet/campaigns/<id>.yml)",
        )
        sp.add_argument(
            "--clones-dir",
            default=None,
            help="Directory containing local vNNN/rNNN clones",
        )
        sp.add_argument(
            "--repo",
            action="append",
            default=[],
            help="Explicit volume repo path (repeatable)",
        )
        sp.add_argument(
            "--format",
            choices=("text", "json"),
            default="text",
            help="Output format (default: text)",
        )
        sp.add_argument(
            "--papersite-root",
            default=None,
            help="Papersite checkout (default: PAPERSITE_ROOT or auto-detect)",
        )

    inv = sub.add_parser("inventory", help="Classify repos for a campaign")
    add_common(inv)
    inv.set_defaults(func=cmd_inventory)

    plan = sub.add_parser("plan", help="Dry-run actions for missing repos")
    add_common(plan)
    plan.set_defaults(func=cmd_plan)

    apply = sub.add_parser(
        "apply",
        help="Open PRs (not implemented yet; requires --open-prs later)",
    )
    add_common(apply)
    apply.add_argument(
        "--open-prs",
        action="store_true",
        help="Required for mutation once apply is implemented",
    )
    apply.set_defaults(func=cmd_apply)

    return p


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return int(args.func(args))


if __name__ == "__main__":
    sys.exit(main())
