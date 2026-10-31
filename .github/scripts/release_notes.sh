#!/usr/bin/env bash
# Prints the CHANGELOG.md section for a version, e.g. `release_notes.sh 2.1.0`.
# Fails if the section is missing or empty, so a release can't go out without notes.
set -euo pipefail

version="${1:?usage: release_notes.sh <version>}"
changelog="${2:-CHANGELOG.md}"

# Exact match on "## [X.Y.Z]" (no regex, so dots in the version are literal);
# the section ends at the next "## [" heading. Leading and trailing blank
# lines are dropped.
notes=$(awk -v heading="## [${version}]" '
  index($0, heading) == 1 { found = 1; next }
  found && index($0, "## [") == 1 { exit }
  found && !started && $0 ~ /^[[:space:]]*$/ { next }
  found { started = 1; print }
' "$changelog")

if ! printf '%s' "$notes" | grep -q '[^[:space:]]'; then
  echo "::error::No CHANGELOG.md section for version ${version}" >&2
  exit 1
fi

printf '%s\n' "$notes"
