#!/bin/bash

# ============================================================================
# Check Volume Script - Pre-publication validation for PMLR volumes
# ============================================================================
#
# PURPOSE:
#   Validates that a volume directory is ready for publication by checking:
#   - All BibTeX keys have matching PDF files in the repository root
#   - No PDFs are stranded in subdirectories (e.g. pdfs/, supplementary_material/)
#   - Supplementary files are in the root (not in subdirectories)
#   - @Proceedings entry has required fields (published, name, volume in braces)
#   - Author names are well-formed (Surname, Given format)
#   - No double backslashes or escaped $ / { } / _ in abstracts
#   - No non-ASCII characters in BibTeX keys
#
# USAGE:
#   cd ~/mlresearch/vNNN
#   ../papersite/bin/check_volume.sh NNN [BIBFILE]
#
#   Or from anywhere:
#   ~/mlresearch/papersite/bin/check_volume.sh NNN [BIBFILE]
#
# ARGUMENTS:
#   NNN      Volume number (e.g. 304)
#   BIBFILE  Optional: BibTeX filename (default: auto-detected)
#
# EXIT CODES:
#   0  All checks passed
#   1  One or more checks failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"

VOLUME="${1:-}"
BIBFILE="${2:-}"

if [[ -z "$VOLUME" ]]; then
  echo "Usage: check_volume.sh VOLUME [BIBFILE]"
  echo "  Must be run from the volume directory, or the volume directory must exist"
  exit 1
fi

# Determine volume directory
if [[ -d "v${VOLUME}" ]]; then
  VOL_DIR="$(pwd)/v${VOLUME}"
elif [[ "$(basename $(pwd))" == "v${VOLUME}" ]]; then
  VOL_DIR="$(pwd)"
elif [[ -d "${VOLUME}" ]]; then
  VOL_DIR="$(pwd)/${VOLUME}"
else
  echo "ERROR: Cannot find volume directory for volume ${VOLUME}"
  exit 1
fi

ruby "$LIB_DIR/check_volume.rb" -v "$VOLUME" -d "$VOL_DIR" ${BIBFILE:+-b "$BIBFILE"}
