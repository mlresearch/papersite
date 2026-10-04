"""Unit tests for lib/pmfleet.py (CIP-000A inventory/plan/apply/status)."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path
from types import SimpleNamespace

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "lib"))

import pmfleet  # noqa: E402


FIXTURES = ROOT / "tests" / "fixtures" / "fleet"


def _cli_env() -> dict:
    env = os.environ.copy()
    env["PMFLEET_PYTHON"] = sys.executable
    return env


@pytest.fixture(scope="module")
def posts_campaign():
    return pmfleet.Campaign.load(
        ROOT / "fleet" / "campaigns" / "pmlint-posts-ci.yml"
    )


@pytest.fixture(scope="module")
def intake_campaign():
    return pmfleet.Campaign.load(
        ROOT / "fleet" / "campaigns" / "pmlint-intake-ci.yml"
    )


def test_classify_posts_missing(posts_campaign):
    r = pmfleet.classify_repo(posts_campaign, FIXTURES / "v99001", ROOT)
    assert r.classification == "missing"
    assert r.actions and r.actions[0]["action"] == "open_pr"
    assert r.target_branch == "gh-pages"


def test_classify_posts_match(posts_campaign):
    r = pmfleet.classify_repo(posts_campaign, FIXTURES / "v99002", ROOT)
    assert r.classification == "match"


def test_classify_posts_custom(posts_campaign):
    r = pmfleet.classify_repo(posts_campaign, FIXTURES / "v99003", ROOT)
    assert r.classification == "custom"


def test_classify_posts_skip_unpublished(posts_campaign):
    r = pmfleet.classify_repo(posts_campaign, FIXTURES / "v99004", ROOT)
    assert r.classification == "skip"


def test_classify_intake_missing(intake_campaign):
    r = pmfleet.classify_repo(intake_campaign, FIXTURES / "v99005", ROOT)
    assert r.classification == "missing"
    assert r.target_branch == "default"


def test_classify_intake_skip_published(intake_campaign):
    r = pmfleet.classify_repo(intake_campaign, FIXTURES / "v99006", ROOT)
    assert r.classification == "skip"


def test_plan_only_missing(posts_campaign):
    repos = [
        FIXTURES / "v99001",
        FIXTURES / "v99002",
        FIXTURES / "v99003",
        FIXTURES / "v99004",
    ]
    results = [pmfleet.classify_repo(posts_campaign, r, ROOT) for r in repos]
    plan = pmfleet.build_plan(results)
    assert [p["repo"] for p in plan] == ["v99001"]


def test_cli_inventory_json():
    proc = subprocess.run(
        [
            str(ROOT / "bin" / "pmfleet"),
            "inventory",
            "--campaign",
            "pmlint-posts-ci",
            "--clones-dir",
            str(FIXTURES),
            "--format",
            "json",
            "--papersite-root",
            str(ROOT),
        ],
        capture_output=True,
        text=True,
        check=False,
        env=_cli_env(),
    )
    assert proc.returncode == 0, proc.stderr
    data = json.loads(proc.stdout)
    assert data["read_only"] is True
    by_name = {r["name"]: r["classification"] for r in data["repos"]}
    assert by_name["v99001"] == "missing"
    assert by_name["v99002"] == "match"
    assert by_name["v99003"] == "custom"
    assert by_name["v99004"] == "skip"


def test_cli_plan_json():
    proc = subprocess.run(
        [
            str(ROOT / "bin" / "pmfleet"),
            "plan",
            "--campaign",
            "pmlint-posts-ci",
            "--repo",
            str(FIXTURES / "v99001"),
            "--repo",
            str(FIXTURES / "v99002"),
            "--format",
            "json",
            "--papersite-root",
            str(ROOT),
        ],
        capture_output=True,
        text=True,
        check=False,
        env=_cli_env(),
    )
    assert proc.returncode == 0, proc.stderr
    data = json.loads(proc.stdout)
    assert data["would_mutate"] is False
    assert len(data["planned"]) == 1
    assert data["planned"][0]["repo"] == "v99001"


def test_cli_apply_refuses_without_open_prs():
    proc = subprocess.run(
        [
            str(ROOT / "bin" / "pmfleet"),
            "apply",
            "--campaign",
            "pmlint-posts-ci",
            "--repo",
            str(FIXTURES / "v99001"),
            "--papersite-root",
            str(ROOT),
        ],
        capture_output=True,
        text=True,
        check=False,
        env=_cli_env(),
    )
    assert proc.returncode == 2
    assert "--open-prs" in proc.stderr


class ScriptedRunner(pmfleet.Runner):
    """Real git; stubbed gh."""

    def __init__(self, pr_list_json: str = "[]", create_url: str = "https://example.test/pr/1"):
        self.pr_list_json = pr_list_json
        self.create_url = create_url
        self.calls: list[list[str]] = []

    def run(self, args, *, cwd=None, check=True, env=None):
        self.calls.append(list(args))
        if args and args[0] == "gh":
            if args[1:3] == ["pr", "list"]:
                return subprocess.CompletedProcess(
                    args, 0, self.pr_list_json, ""
                )
            if args[1:3] == ["pr", "create"]:
                return subprocess.CompletedProcess(
                    args, 0, self.create_url + "\n", ""
                )
            return subprocess.CompletedProcess(args, 1, "", "unexpected gh")
        return super().run(args, cwd=cwd, check=check, env=env)


def _git(cwd: Path, *args: str) -> None:
    subprocess.run(
        ["git", *args], cwd=cwd, check=True, capture_output=True, text=True
    )


def _init_published_volume(tmp_path: Path, name: str = "v99011") -> Path:
    bare = tmp_path / f"{name}.git"
    work = tmp_path / name
    work.mkdir(parents=True)
    _git(work, "init", "-b", "main")
    (work / "README.md").write_text(f"# {name}\n", encoding="utf-8")
    _git(
        work,
        "-c",
        "user.email=test@example.com",
        "-c",
        "user.name=Test",
        "add",
        "README.md",
    )
    _git(
        work,
        "-c",
        "user.email=test@example.com",
        "-c",
        "user.name=Test",
        "commit",
        "-m",
        "init main",
    )
    _git(tmp_path, "init", "--bare", str(bare))
    _git(work, "remote", "add", "origin", str(bare))
    _git(work, "push", "-u", "origin", "main")
    _git(work, "checkout", "-b", "gh-pages")
    (work / "_posts").mkdir()
    (work / "_posts" / ".keep").write_text("", encoding="utf-8")
    (work / ".pmfleet-published").write_text("", encoding="utf-8")
    _git(work, "add", "_posts", ".pmfleet-published")
    _git(
        work,
        "-c",
        "user.email=test@example.com",
        "-c",
        "user.name=Test",
        "commit",
        "-m",
        "init gh-pages",
    )
    _git(work, "push", "-u", "origin", "gh-pages")
    _git(work, "remote", "set-head", "origin", "main")
    return work


def test_apply_opens_pr_with_scripted_gh(tmp_path, posts_campaign):
    work = _init_published_volume(tmp_path)
    runner = ScriptedRunner()
    slept: list[float] = []
    result = pmfleet.apply_one_repo(
        posts_campaign,
        work,
        ROOT,
        runner,
        sleep_fn=slept.append,
        rate_limit_s=1.5,
    )
    assert result.outcome == "opened", result.detail
    assert result.pr_url == "https://example.test/pr/1"
    assert slept == [1.5]
    dest = work / ".github" / "workflows" / "pmlint-posts.yml"
    assert dest.is_file()
    assert "pmlint-posts" in dest.read_text(encoding="utf-8")
    # No force on push
    push_calls = [c for c in runner.calls if c[:2] == ["git", "push"]]
    assert push_calls
    assert all("--force" not in c for c in push_calls)


def test_apply_skips_when_pr_open(tmp_path, posts_campaign):
    work = _init_published_volume(tmp_path, name="v99012")
    runner = ScriptedRunner(
        pr_list_json=json.dumps(
            [
                {
                    "number": 3,
                    "url": "https://example.test/pr/3",
                    "state": "OPEN",
                    "mergedAt": None,
                    "baseRefName": "gh-pages",
                    "headRefName": posts_campaign.pr_branch,
                }
            ]
        )
    )
    result = pmfleet.apply_one_repo(
        posts_campaign, work, ROOT, runner, rate_limit_s=0
    )
    assert result.outcome == "skipped_pr_open"
    assert not (work / ".github" / "workflows" / "pmlint-posts.yml").exists()


def test_apply_skips_custom_and_match(posts_campaign):
    runner = ScriptedRunner()
    custom = pmfleet.apply_one_repo(
        posts_campaign, FIXTURES / "v99003", ROOT, runner, rate_limit_s=0
    )
    match = pmfleet.apply_one_repo(
        posts_campaign, FIXTURES / "v99002", ROOT, runner, rate_limit_s=0
    )
    assert custom.outcome == "skipped_custom"
    assert match.outcome == "skipped_match"


def test_apply_limit(tmp_path, posts_campaign):
    a = _init_published_volume(tmp_path / "a", name="v99013")
    b = _init_published_volume(tmp_path / "b", name="v99014")
    runner = ScriptedRunner()
    results = pmfleet._apply_with_limit(
        posts_campaign,
        [a, b],
        ROOT,
        runner,
        limit=1,
        rate_limit_s=0,
        sleep_fn=lambda _s: None,
    )
    outcomes = {r.repo: r.outcome for r in results}
    assert outcomes["v99013"] == "opened"
    assert outcomes["v99014"] == "skipped_limit"


def test_status_reports_pr_and_gap(tmp_path, posts_campaign):
    work = _init_published_volume(tmp_path, name="v99015")
    runner = ScriptedRunner(
        pr_list_json=json.dumps(
            [
                {
                    "number": 9,
                    "url": "https://example.test/pr/9",
                    "state": "OPEN",
                    "mergedAt": None,
                    "baseRefName": "gh-pages",
                    "headRefName": posts_campaign.pr_branch,
                }
            ]
        )
    )
    args = SimpleNamespace(
        campaign="pmlint-posts-ci",
        clones_dir=None,
        repo=[str(work)],
        format="json",
        papersite_root=str(ROOT),
        runner=runner,
    )
    # Capture stdout
    import io
    from contextlib import redirect_stdout

    buf = io.StringIO()
    with redirect_stdout(buf):
        rc = pmfleet.cmd_status(args)
    assert rc == 0
    data = json.loads(buf.getvalue())
    assert data["repos"][0]["classification"] == "missing"
    assert data["repos"][0]["pr_state"] == "open"
    assert data["gap_count"] == 0
