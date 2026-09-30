#!/usr/bin/env bash
# =============================================================================
# check_volume.sh - Pre-publication validation for PMLR volumes
# =============================================================================
#
# USAGE:
#   cd ~/mlresearch/v304
#   ../papersite/bin/check_volume.sh            # id from directory name
#   ../papersite/bin/check_volume.sh v304
#   ../papersite/bin/check_volume.sh 304        # same as v304
#   ../papersite/bin/check_volume.sh r0         # rerelease repos
#   ../papersite/bin/check_volume.sh v304 proceedings.bib
#
# Volume ids are vNNN or rNNN (rereleases). A bare number means v<number>.
#
# EXIT CODES:
#   0  All checks passed
#   1  One or more checks failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"

VOLUME_ARG="${1:-}"
BIBFILE="${2:-}"

normalize_volume_id() {
  local raw="$1"
  if [[ "$raw" =~ ^[0-9]+$ ]]; then
    printf 'v%s\n' "$raw"
  elif [[ "$raw" =~ ^[vr][0-9]+$ ]]; then
    printf '%s\n' "$raw"
  else
    return 1
  fi
}

infer_volume_id() {
  local name
  name="$(basename "$(pwd)")"
  if normalize_volume_id "$name" >/dev/null 2>&1; then
    normalize_volume_id "$name"
    return
  fi
  return 1
}

VOLUME_ID=""
if [[ -n "$VOLUME_ARG" ]]; then
  if ! VOLUME_ID="$(normalize_volume_id "$VOLUME_ARG")"; then
    echo "ERROR: Volume must be vNNN, rNNN, or a bare number (got: $VOLUME_ARG)" >&2
    exit 1
  fi
else
  if ! VOLUME_ID="$(infer_volume_id)"; then
    echo "Usage: check_volume.sh [VOLUME] [BIBFILE]" >&2
    echo "  VOLUME  vNNN / rNNN / bare number (default: current directory name)" >&2
    exit 1
  fi
fi

# Determine volume directory
if [[ -d "$VOLUME_ID" ]]; then
  VOL_DIR="$(cd "$VOLUME_ID" && pwd)"
elif [[ "$(basename "$(pwd)")" == "$VOLUME_ID" ]]; then
  VOL_DIR="$(pwd)"
elif [[ "$VOLUME_ID" == v* && -d "${VOLUME_ID#v}" ]]; then
  # rare: cwd layout uses bare number directory
  VOL_DIR="$(cd "${VOLUME_ID#v}" && pwd)"
else
  echo "ERROR: Cannot find volume directory for ${VOLUME_ID}" >&2
  exit 1
fi

ruby "$LIB_DIR/check_volume.rb" -v "$VOLUME_ID" -d "$VOL_DIR" ${BIBFILE:+-b "$BIBFILE"}
