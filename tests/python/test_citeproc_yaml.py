"""Regression test: every published volume's citeproc.yaml must load in Python.

``mlresearch.github.io`` generates a site-wide index, ``proceedings.yaml``,
listing every published PMLR volume. Each entry points at that volume's own
generated bibliography feed, ``assets/bib/citeproc.yaml`` (produced by the
``mlresearch/jekyll-theme`` remote theme from the volume's Jekyll posts).

This test fetches the live ``proceedings.yaml`` index, then fetches and
parses every linked ``citeproc.yaml`` file with PyYAML's ``safe_load`` to
confirm each one is loadable, well-formed YAML.

Requires network access to https://proceedings.mlr.press. If the index
itself cannot be reached, the whole module is skipped rather than failed,
since that indicates an environment/connectivity problem rather than a
data problem with a specific volume.

Run with:
    cd tests/python
    python3 -m venv ../../.venv   # once, from the papersite root
    source ../../.venv/bin/activate
    pip install -r requirements.txt
    pytest -v test_citeproc_yaml.py
"""

from __future__ import annotations

import urllib.error
import urllib.request
from typing import Any

import pytest
import yaml

PROCEEDINGS_URL = "https://proceedings.mlr.press/proceedings.yaml"
REQUEST_TIMEOUT_SECONDS = 20
USER_AGENT = "papersite-tests/1.0 (+https://github.com/mlresearch/papersite)"


def _fetch_text(url: str) -> str:
    """Fetch ``url`` and return its body decoded as UTF-8 text."""
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=REQUEST_TIMEOUT_SECONDS) as response:
        return response.read().decode("utf-8")


def _load_proceedings_entries() -> list[dict[str, Any]]:
    """Fetch and parse the site-wide proceedings index.

    Skips the whole module (rather than failing) if the index cannot be
    reached at all, since that points to a connectivity problem, not a
    per-volume data problem.
    """
    try:
        raw = _fetch_text(PROCEEDINGS_URL)
    except (urllib.error.URLError, OSError) as exc:
        pytest.skip(f"Could not reach {PROCEEDINGS_URL}: {exc}", allow_module_level=True)

    try:
        entries = yaml.safe_load(raw)
    except yaml.YAMLError as exc:
        pytest.fail(f"{PROCEEDINGS_URL} is not valid YAML: {exc}")

    if not isinstance(entries, list) or not entries:
        pytest.fail(
            f"Expected a non-empty list of volumes from {PROCEEDINGS_URL}, "
            f"got {type(entries).__name__}"
        )
    return entries


def _volume_test_id(entry: dict[str, Any]) -> str:
    """Build a readable pytest ID like 'v339' for a proceedings.yaml entry."""
    return f"v{entry.get('volume', '?')}"


PROCEEDINGS_ENTRIES = _load_proceedings_entries()

pytestmark = pytest.mark.network


@pytest.mark.parametrize(
    "entry",
    PROCEEDINGS_ENTRIES,
    ids=[_volume_test_id(entry) for entry in PROCEEDINGS_ENTRIES],
)
def test_citeproc_yaml_is_loadable(entry: dict[str, Any]) -> None:
    """Each volume's citeproc.yaml must fetch and parse as valid YAML."""
    yaml_url = entry.get("yaml")
    assert yaml_url, f"proceedings.yaml entry for {entry.get('volume')} has no 'yaml' key: {entry}"

    try:
        raw = _fetch_text(yaml_url)
    except (urllib.error.URLError, OSError) as exc:
        pytest.fail(f"Could not fetch {yaml_url}: {exc}")

    try:
        papers = yaml.safe_load(raw)
    except yaml.YAMLError as exc:
        pytest.fail(f"{yaml_url} is not valid YAML: {exc}")

    assert papers is not None, f"{yaml_url} parsed to None (empty YAML document?)"
    assert isinstance(papers, list), (
        f"{yaml_url} should parse to a list of paper entries, "
        f"got {type(papers).__name__}"
    )
