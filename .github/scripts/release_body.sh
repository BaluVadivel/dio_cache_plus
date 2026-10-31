#!/usr/bin/env bash
# Prints the GitHub Release body for a tag, e.g. `release_body.sh v2.1.0`:
# the version's CHANGELOG.md section, then a link to all code changes since
# the previous version tag.
# Needs the repository's tags locally and GITHUB_REPOSITORY (owner/repo).
set -euo pipefail

tag="${1:?usage: release_body.sh <tag>}"
repo="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY must be set}"
version="${tag#v}"
dir="$(cd "$(dirname "$0")" && pwd)"

bash "$dir/release_notes.sh" "$version"

# Previous release = the next lower vX.Y.Z tag by version, not by date.
# The current tag is added to the list in case it isn't present locally.
previous=$({ git tag --list 'v[0-9]*.[0-9]*.[0-9]*'; echo "$tag"; } |
  sort -u -V -r |
  awk -v current="$tag" 'found { print; exit } $0 == current { found = 1 }')

if [ -n "$previous" ]; then
  echo
  echo "**All code changes since ${previous#v}**: [${previous}...${tag}](https://github.com/${repo}/compare/${previous}...${tag})"
fi
