# Python Tests — Live Site Data Validation

This directory contains Python tests that validate *deployed* PMLR data,
as opposed to `test/` (Ruby, tests `lib/tidy_bibtex.rb` etc.) and the rest
of `tests/` (Bash, regression tests for `lib/check_volume.rb`). Unlike
those two suites, these tests hit the live `https://proceedings.mlr.press`
site over the network rather than exercising local code against fixtures.

## What's Tested

### `test_citeproc_yaml.py`

`mlresearch.github.io` generates a site-wide `proceedings.yaml` index
listing every published volume, each with a link to that volume's own
generated bibliography feed at `assets/bib/citeproc.yaml` (produced by the
`mlresearch/jekyll-theme` remote theme). This test fetches the index and
then every linked `citeproc.yaml`, confirming each one loads as valid YAML
via `yaml.safe_load`.

If `proceedings.yaml` itself is unreachable, the whole module is skipped
(treated as a connectivity problem). If an individual volume's
`citeproc.yaml` fails to fetch or parse, only that volume's parametrized
test case fails — the rest still run.

## Setup

From the `papersite` repository root (**not** inside `tests/python`):

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r tests/python/requirements.txt
```

This project virtualenv (`papersite/.venv`) is separate from
`.venv-vibesafe`, which is reserved exclusively for VibeSafe's own tooling
(`whats-next`, `backlog/update_index.py`, etc.) — see the VibeSafe Python
Environment Awareness convention.

## Running

```bash
source .venv/bin/activate
pytest tests/python -v
deactivate
```

To run just the citeproc.yaml check:

```bash
pytest tests/python/test_citeproc_yaml.py -v
```

To see which volumes failed at a glance, without full tracebacks:

```bash
pytest tests/python/test_citeproc_yaml.py -q
```

## Notes

- This suite is **not** wired into `test/run_tests.rb` or the bash
  regression suite in `tests/`, since it requires network access and can
  take a couple of minutes (it currently checks ~330 volumes).
- It is also not yet part of CI. See
  [CIP-0006](../../cip/cip0006.md) for a proposal to move self-validation
  like this closer to each volume (e.g. as part of the shared theme or
  volume-creation workflow) rather than checking every volume centrally
  from `papersite`.
