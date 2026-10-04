"""Unit tests for lib/pmfleet.py (CIP-000A inventory/plan)."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

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
    r = pmfleet.classify_repo(posts_campaign, FIXTURES / "v901", ROOT)
    assert r.classification == "missing"
    assert r.actions and r.actions[0]["action"] == "open_pr"
    assert r.target_branch == "gh-pages"


def test_classify_posts_match(posts_campaign):
    r = pmfleet.classify_repo(posts_campaign, FIXTURES / "v902", ROOT)
    assert r.classification == "match"


def test_classify_posts_custom(posts_campaign):
    r = pmfleet.classify_repo(posts_campaign, FIXTURES / "v903", ROOT)
    assert r.classification == "custom"


def test_classify_posts_skip_unpublished(posts_campaign):
    r = pmfleet.classify_repo(posts_campaign, FIXTURES / "v904", ROOT)
    assert r.classification == "skip"


def test_classify_intake_missing(intake_campaign):
    r = pmfleet.classify_repo(intake_campaign, FIXTURES / "v905", ROOT)
    assert r.classification == "missing"
    assert r.target_branch == "default"


def test_classify_intake_skip_published(intake_campaign):
    r = pmfleet.classify_repo(intake_campaign, FIXTURES / "v906", ROOT)
    assert r.classification == "skip"


def test_plan_only_missing(posts_campaign):
    repos = [
        FIXTURES / "v901",
        FIXTURES / "v902",
        FIXTURES / "v903",
        FIXTURES / "v904",
    ]
    results = [pmfleet.classify_repo(posts_campaign, r, ROOT) for r in repos]
    plan = pmfleet.build_plan(results)
    assert [p["repo"] for p in plan] == ["v901"]


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
    assert by_name["v901"] == "missing"
    assert by_name["v902"] == "match"
    assert by_name["v903"] == "custom"
    assert by_name["v904"] == "skip"


def test_cli_plan_json():
    proc = subprocess.run(
        [
            str(ROOT / "bin" / "pmfleet"),
            "plan",
            "--campaign",
            "pmlint-posts-ci",
            "--repo",
            str(FIXTURES / "v901"),
            "--repo",
            str(FIXTURES / "v902"),
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
    assert data["planned"][0]["repo"] == "v901"


def test_cli_apply_not_implemented():
    proc = subprocess.run(
        [
            str(ROOT / "bin" / "pmfleet"),
            "apply",
            "--campaign",
            "pmlint-posts-ci",
            "--repo",
            str(FIXTURES / "v901"),
            "--open-prs",
            "--papersite-root",
            str(ROOT),
        ],
        capture_output=True,
        text=True,
        check=False,
        env=_cli_env(),
    )
    assert proc.returncode == 2
