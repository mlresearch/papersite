#!/usr/bin/env bash
# Install papersite-owned pmlint workflow copies into a volume checkout.
# Source of truth remains papersite .github/workflows/*-example.yml files.
#
# Usage:
#   install_volume_workflows.sh intake [VOLUME_DIR]
#   install_volume_workflows.sh posts  [VOLUME_DIR]
#   install_volume_workflows.sh both   [VOLUME_DIR]
set -euo pipefail

MODE="${1:-}"
VOLUME_DIR="${2:-.}"

usage() {
  cat <<'EOF'
Usage:
  install_volume_workflows.sh intake|posts|both [VOLUME_DIR]

Copies campaign source workflows from papersite into the volume:
  intake → .github/workflows/pmlint.yml
  posts  → .github/workflows/pmlint-posts.yml

PAPERSITE_ROOT overrides papersite location (default: sibling ../papersite
or the parent of this script).
EOF
}

if [[ -z "$MODE" || "$MODE" == "-h" || "$MODE" == "--help" ]]; then
  usage
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -n "${PAPERSITE_ROOT:-}" ]]; then
  ROOT="$(cd "$PAPERSITE_ROOT" && pwd)"
elif [[ -d "${SCRIPT_DIR}/../.github/workflows" ]]; then
  ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
elif [[ -d "${VOLUME_DIR}/../papersite/.github/workflows" ]]; then
  ROOT="$(cd "${VOLUME_DIR}/../papersite" && pwd)"
else
  echo "ERROR: Could not locate papersite (set PAPERSITE_ROOT)" >&2
  exit 1
fi

VOLUME_DIR="$(cd "$VOLUME_DIR" && pwd)"
WF_DIR="${VOLUME_DIR}/.github/workflows"
mkdir -p "$WF_DIR"

install_one() {
  local kind="$1"
  local src dest
  case "$kind" in
    intake)
      src="${ROOT}/.github/workflows/pmlint-volume-example.yml"
      dest="${WF_DIR}/pmlint.yml"
      ;;
    posts)
      src="${ROOT}/.github/workflows/pmlint-posts-volume-example.yml"
      dest="${WF_DIR}/pmlint-posts.yml"
      ;;
    *)
      echo "ERROR: unknown kind: $kind" >&2
      exit 1
      ;;
  esac
  if [[ ! -f "$src" ]]; then
    echo "ERROR: missing source workflow: $src" >&2
    exit 1
  fi
  /bin/cp -f "$src" "$dest"
  echo "Installed $kind workflow → ${dest#"$VOLUME_DIR"/}"
}

case "$MODE" in
  intake) install_one intake ;;
  posts) install_one posts ;;
  both)
    install_one intake
    install_one posts
    ;;
  *)
    echo "ERROR: mode must be intake, posts, or both (got: $MODE)" >&2
    usage >&2
    exit 1
    ;;
esac
