#!/usr/bin/env python3
"""pmfleet — inventory / plan / apply / status for fleet rollouts (CIP-000A).

inventory and plan are read-only. apply mutates only with --open-prs and
opens branch+PR (never force-pushes to main/gh-pages).
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Callable, Dict, Iterable, List, Optional, Sequence, Tuple

try:
    import yaml
except ImportError as exc:  # pragma: no cover
    raise SystemExit(
        "pmfleet requires PyYAML. Install with:\n"
        "  python3 -m pip install -r tests/python/requirements.txt"
    ) from exc


VOLUME_NAME_RE = re.compile(r"^[vr]\d+$")
PROTECTED_BRANCHES = frozenset({"main", "master", "gh-pages"})


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


@dataclass
class ApplyResult:
    repo: str
    path: str
    outcome: str
    detail: str
    pr_url: Optional[str] = None


@dataclass
class StatusRow:
    repo: str
    path: str
    classification: str
    pr_state: str
    detail: str
    target_branch: str


class CommandError(RuntimeError):
    def __init__(self, message: str, stdout: str = "", stderr: str = ""):
        super().__init__(message)
        self.stdout = stdout
        self.stderr = stderr


class Runner:
    """subprocess runner; tests inject fakes."""

    def run(
        self,
        args: Sequence[str],
        *,
        cwd: Optional[Path] = None,
        check: bool = True,
        env: Optional[Dict[str, str]] = None,
    ) -> subprocess.CompletedProcess:
        merged = os.environ.copy()
        if env:
            merged.update(env)
        proc = subprocess.run(
            list(args),
            cwd=str(cwd) if cwd else None,
            text=True,
            capture_output=True,
            env=merged,
            check=False,
        )
        if check and proc.returncode != 0:
            raise CommandError(
                f"command failed ({proc.returncode}): {' '.join(args)}\n"
                f"{proc.stderr or proc.stdout}",
                stdout=proc.stdout,
                stderr=proc.stderr,
            )
        return proc


def papersite_root_from_argv_env(explicit: Optional[str] = None) -> Path:
    if explicit:
        return Path(explicit).resolve()
    env = os.environ.get("PAPERSITE_ROOT")
    if env:
        return Path(env).resolve()
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

    if campaign.custom_regexes:
        patterns = [re.compile(rx, re.I) for rx in campaign.custom_regexes]
        for wf in workflow_files(repo):
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
    print(f"{'REPO':<12} {'CLASS':<10} {'BASE':<16} REASON")
    print("-" * 72)
    for r in results:
        print(f"{r.name:<12} {r.classification:<10} {r.target_branch:<16} {r.reason}")
    print("-" * 72)
    print(
        "totals: "
        + ", ".join(f"{k}={v}" for k, v in counts.items() if v or k in counts)
    )


class NoReposError(RuntimeError):
    pass


def _require_repos(args: argparse.Namespace) -> List[Path]:
    repos = discover_repos(
        Path(args.clones_dir) if args.clones_dir else None,
        [Path(p) for p in (args.repo or [])],
    )
    if not repos:
        raise NoReposError(
            "ERROR: No volume repos found. Pass --repo and/or --clones-dir "
            "containing vNNN/rNNN directories."
        )
    return repos


def git(
    runner: Runner,
    repo: Path,
    *git_args: str,
    check: bool = True,
    env: Optional[Dict[str, str]] = None,
) -> subprocess.CompletedProcess:
    return runner.run(["git", *git_args], cwd=repo, check=check, env=env)


GIT_IDENTITY = {
    "GIT_AUTHOR_NAME": "pmfleet",
    "GIT_AUTHOR_EMAIL": "pmfleet@users.noreply.github.com",
    "GIT_COMMITTER_NAME": "pmfleet",
    "GIT_COMMITTER_EMAIL": "pmfleet@users.noreply.github.com",
}


def resolve_base_branch(
    runner: Runner, repo: Path, target: str
) -> str:
    if target != "default":
        return target
    proc = git(
        runner,
        repo,
        "symbolic-ref",
        "--quiet",
        "--short",
        "refs/remotes/origin/HEAD",
        check=False,
    )
    if proc.returncode == 0:
        ref = proc.stdout.strip()
        if ref.startswith("origin/"):
            return ref.split("/", 1)[1]
    for candidate in ("main", "master"):
        probe = git(
            runner,
            repo,
            "rev-parse",
            "--verify",
            f"origin/{candidate}",
            check=False,
        )
        if probe.returncode == 0:
            return candidate
    return "main"


def pr_states_for_head(
    runner: Runner, repo: Path, head_branch: str
) -> List[dict]:
    """Return gh pr list entries for head branch (open + closed/merged)."""
    proc = runner.run(
        [
            "gh",
            "pr",
            "list",
            "--state",
            "all",
            "--head",
            head_branch,
            "--json",
            "number,url,state,mergedAt,baseRefName,headRefName",
        ],
        cwd=repo,
        check=False,
    )
    if proc.returncode != 0:
        return []
    try:
        data = json.loads(proc.stdout or "[]")
    except json.JSONDecodeError:
        return []
    return data if isinstance(data, list) else []


def summarize_pr_state(prs: List[dict]) -> Tuple[str, str]:
    """Return (state, detail) where state is none|open|merged|closed."""
    if not prs:
        return "none", "no PR for campaign head branch"
    # Prefer open, then merged, then closed
    for pr in prs:
        if pr.get("state") == "OPEN":
            return "open", pr.get("url") or f"#{pr.get('number')}"
    for pr in prs:
        if pr.get("mergedAt") or pr.get("state") == "MERGED":
            return "merged", pr.get("url") or f"#{pr.get('number')}"
    pr = prs[0]
    return "closed", pr.get("url") or f"#{pr.get('number')}"


def copy_campaign_files(campaign: Campaign, papersite: Path, repo: Path) -> List[Path]:
    written: List[Path] = []
    for mapping in campaign.source:
        src = papersite / mapping.papersite
        dest = repo / mapping.dest
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dest)
        written.append(dest)
    return written


def apply_one_repo(
    campaign: Campaign,
    repo: Path,
    papersite: Path,
    runner: Runner,
    *,
    sleep_fn: Callable[[float], None] = time.sleep,
    rate_limit_s: float = 0.0,
) -> ApplyResult:
    classified = classify_repo(campaign, repo, papersite)
    if classified.classification != "missing":
        return ApplyResult(
            repo=repo.name,
            path=str(repo),
            outcome=f"skipped_{classified.classification}",
            detail=classified.reason,
        )

    if not (repo / ".git").exists():
        return ApplyResult(
            repo=repo.name,
            path=str(repo),
            outcome="error",
            detail="not a git repository",
        )

    head = campaign.pr_branch
    if head in PROTECTED_BRANCHES:
        return ApplyResult(
            repo=repo.name,
            path=str(repo),
            outcome="error",
            detail=f"refusing to use protected branch name as PR head: {head}",
        )

    prs = pr_states_for_head(runner, repo, head)
    pr_state, pr_detail = summarize_pr_state(prs)
    if pr_state == "open":
        return ApplyResult(
            repo=repo.name,
            path=str(repo),
            outcome="skipped_pr_open",
            detail=pr_detail,
            pr_url=pr_detail if pr_detail.startswith("http") else None,
        )
    if pr_state == "merged":
        return ApplyResult(
            repo=repo.name,
            path=str(repo),
            outcome="skipped_pr_merged",
            detail=pr_detail,
            pr_url=pr_detail if pr_detail.startswith("http") else None,
        )

    base = resolve_base_branch(runner, repo, classified.target_branch)

    try:
        git(runner, repo, "fetch", "origin", check=False)
        # Ensure base exists locally
        git(runner, repo, "rev-parse", "--verify", f"origin/{base}")
        # Create/reset campaign branch from origin/base (local only; push without --force)
        git(runner, repo, "checkout", "-B", head, f"origin/{base}")
        written = copy_campaign_files(campaign, papersite, repo)
        git(runner, repo, "add", "--", *[str(p.relative_to(repo)) for p in written])
        status = git(runner, repo, "status", "--porcelain")
        if not status.stdout.strip():
            return ApplyResult(
                repo=repo.name,
                path=str(repo),
                outcome="skipped_no_changes",
                detail="working tree already matches campaign files on branch",
            )
        msg = f"{campaign.pr_title}\n\nFleet campaign `{campaign.id}` (CIP-000A)."
        git(runner, repo, "commit", "-m", msg, env=GIT_IDENTITY)
        push = git(
            runner,
            repo,
            "push",
            "-u",
            "origin",
            f"refs/heads/{head}:refs/heads/{head}",
            check=False,
        )
        if push.returncode != 0:
            # Never retry with --force
            return ApplyResult(
                repo=repo.name,
                path=str(repo),
                outcome="error",
                detail=(
                    "git push failed (refusing --force). "
                    "Delete or update the remote campaign branch manually if needed.\n"
                    f"{push.stderr or push.stdout}"
                ),
            )

        body = (
            f"Automated fleet apply for campaign `{campaign.id}`.\n\n"
            f"{campaign.title}\n\n"
            "Opened by `pmfleet apply --open-prs` (CIP-000A). "
            "Does not force-push protected branches."
        )
        create = runner.run(
            [
                "gh",
                "pr",
                "create",
                "--base",
                base,
                "--head",
                head,
                "--title",
                campaign.pr_title,
                "--body",
                body,
            ],
            cwd=repo,
            check=False,
        )
        if create.returncode != 0:
            return ApplyResult(
                repo=repo.name,
                path=str(repo),
                outcome="error",
                detail=f"gh pr create failed:\n{create.stderr or create.stdout}",
            )
        url = (create.stdout or "").strip().splitlines()[-1] if create.stdout else ""
        if rate_limit_s > 0:
            sleep_fn(rate_limit_s)
        return ApplyResult(
            repo=repo.name,
            path=str(repo),
            outcome="opened",
            detail=url or "PR created",
            pr_url=url or None,
        )
    except CommandError as exc:
        return ApplyResult(
            repo=repo.name,
            path=str(repo),
            outcome="error",
            detail=str(exc),
        )


def cmd_inventory(args: argparse.Namespace) -> int:
    root = papersite_root_from_argv_env(args.papersite_root)
    campaign = Campaign.load(campaign_path(root, args.campaign))
    repos = _require_repos(args)
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
    repos = _require_repos(args)
    results = [classify_repo(campaign, repo, root) for repo in repos]
    plan = build_plan(results)
    payload = {
        "campaign": campaign.id,
        "papersite_root": str(root),
        "read_only": True,
        "would_mutate": False,
        "planned": plan,
        "skipped": [asdict(r) for r in results if r.classification != "missing"],
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
        print(f"summary: planned={len(plan)} other={len(results) - len(plan)}")
    return 0


def _apply_with_limit(
    campaign: Campaign,
    repos: Sequence[Path],
    papersite: Path,
    runner: Runner,
    *,
    limit: Optional[int],
    rate_limit_s: float,
    sleep_fn: Callable[[float], None],
) -> List[ApplyResult]:
    results: List[ApplyResult] = []
    opened = 0
    for repo in repos:
        classified = classify_repo(campaign, repo, papersite)
        if classified.classification != "missing":
            results.append(
                ApplyResult(
                    repo=repo.name,
                    path=str(repo),
                    outcome=f"skipped_{classified.classification}",
                    detail=classified.reason,
                )
            )
            continue
        if limit is not None and opened >= limit:
            results.append(
                ApplyResult(
                    repo=repo.name,
                    path=str(repo),
                    outcome="skipped_limit",
                    detail=f"hit --limit {limit}",
                )
            )
            continue
        outcome = apply_one_repo(
            campaign,
            repo,
            papersite,
            runner,
            sleep_fn=sleep_fn,
            rate_limit_s=rate_limit_s,
        )
        if outcome.outcome == "opened":
            opened += 1
        results.append(outcome)
    return results


def _emit_apply_results(
    args: argparse.Namespace, payload: dict, results: Sequence[ApplyResult]
) -> int:
    if args.format == "json":
        print(json.dumps(payload, indent=2, sort_keys=True))
    else:
        print(f"apply campaign={payload['campaign']} (--open-prs)")
        for r in results:
            extra = f" {r.pr_url}" if r.pr_url else ""
            print(f"- {r.repo}: {r.outcome} — {r.detail}{extra}")
        counts: Dict[str, int] = {}
        for r in results:
            counts[r.outcome] = counts.get(r.outcome, 0) + 1
        print("summary: " + ", ".join(f"{k}={v}" for k, v in sorted(counts.items())))
    return 0 if all(r.outcome != "error" for r in results) else 1


def cmd_apply(args: argparse.Namespace) -> int:
    if not args.open_prs:
        print(
            "ERROR: apply refuses to mutate without --open-prs.\n"
            "       Use `pmfleet plan` for a dry-run, or re-run with --open-prs.",
            file=sys.stderr,
        )
        return 2

    root = papersite_root_from_argv_env(args.papersite_root)
    campaign = Campaign.load(campaign_path(root, args.campaign))
    repos = _require_repos(args)
    runner = args.runner if getattr(args, "runner", None) else Runner()
    sleep_fn = args.sleep_fn if getattr(args, "sleep_fn", None) else time.sleep
    results = _apply_with_limit(
        campaign,
        repos,
        root,
        runner,
        limit=args.limit,
        rate_limit_s=float(args.rate_limit),
        sleep_fn=sleep_fn,
    )
    payload = {
        "campaign": campaign.id,
        "papersite_root": str(root),
        "read_only": False,
        "open_prs": True,
        "results": [asdict(r) for r in results],
    }
    return _emit_apply_results(args, payload, results)


def cmd_status(args: argparse.Namespace) -> int:
    root = papersite_root_from_argv_env(args.papersite_root)
    campaign = Campaign.load(campaign_path(root, args.campaign))
    repos = _require_repos(args)
    runner = args.runner if getattr(args, "runner", None) else Runner()

    rows: List[StatusRow] = []
    for repo in repos:
        classified = classify_repo(campaign, repo, root)
        if (repo / ".git").exists():
            prs = pr_states_for_head(runner, repo, campaign.pr_branch)
            pr_state, pr_detail = summarize_pr_state(prs)
        else:
            pr_state, pr_detail = "none", "not a git repository"
        rows.append(
            StatusRow(
                repo=repo.name,
                path=str(repo),
                classification=classified.classification,
                pr_state=pr_state,
                detail=pr_detail,
                target_branch=classified.target_branch,
            )
        )

    gap = [
        r
        for r in rows
        if r.classification == "missing" and r.pr_state not in {"open", "merged"}
    ]
    payload = {
        "campaign": campaign.id,
        "papersite_root": str(root),
        "read_only": True,
        "repos": [asdict(r) for r in rows],
        "gap_count": len(gap),
    }
    if args.format == "json":
        print(json.dumps(payload, indent=2, sort_keys=True))
    else:
        print(f"status campaign={campaign.id}")
        print(
            f"{'REPO':<12} {'CLASS':<10} {'PR':<8} DETAIL"
        )
        print("-" * 72)
        for r in rows:
            print(
                f"{r.repo:<12} {r.classification:<10} {r.pr_state:<8} {r.detail}"
            )
        print("-" * 72)
        print(
            f"gap (missing, no open/merged PR): {len(gap)} / {len(rows)}"
        )
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="pmfleet",
        description=(
            "Fleet rollout helper (CIP-000A). "
            "inventory/plan/status are read-only; apply requires --open-prs."
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

    status = sub.add_parser(
        "status", help="Classification plus PR state for campaign head branch"
    )
    add_common(status)
    status.set_defaults(func=cmd_status)

    apply = sub.add_parser(
        "apply",
        help="Open branch+PR for missing repos (requires --open-prs)",
    )
    add_common(apply)
    apply.add_argument(
        "--open-prs",
        action="store_true",
        help="Required explicit flag to create branches and pull requests",
    )
    apply.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Max number of new PRs to open (pilot batches)",
    )
    apply.add_argument(
        "--rate-limit",
        type=float,
        default=2.0,
        help="Seconds to sleep after each successfully opened PR (default: 2)",
    )
    apply.set_defaults(func=cmd_apply)

    return p


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return int(args.func(args))
    except NoReposError as exc:
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
