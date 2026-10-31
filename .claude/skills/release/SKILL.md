---
name: release
description: Prepare a dio_cache_plus release to pub.dev - sync check, tests, version bump, CHANGELOG, publish dry run. Stops before any git or publish action.
disable-model-invocation: true
---

# Release dio_cache_plus

Prepare the release, then stop. Never create branches, stage, commit, tag, push or publish unless the user explicitly asks for that specific action. Approval for one doesn't cover the next.

`main` is protected by a GitHub ruleset: direct pushes are rejected, changes land through a pull request with the `verify` CI check passing, and only the repository admin can create `v*` tags.

## 1. Make sure we're releasing from the latest code
- Run `git fetch origin` (only updates remote-tracking refs), then `git status -sb`. Start from `main` matching `origin/main`; if it's behind, ahead or diverged, stop and tell the user. Releasing from stale code would undo published changes.
- Check the latest published version: `curl -s https://pub.dev/api/packages/dio_cache_plus | python3 -c "import json,sys; print(json.load(sys.stdin)['latest']['version'])"`. If it's newer than `version:` in `pubspec.yaml`, stop and tell the user.
- The working tree must be clean apart from release edits. If not, list what's uncommitted and ask whether it belongs in this release.

## 2. Verify quality
- `flutter analyze`: no issues.
- `flutter test`: all pass. Report failures with output; don't continue past them.
- `dart format --output=none --set-exit-if-changed lib test example/lib`: report unformatted files (same check as CI).
- Review the changes since the last tag (`git log $(git describe --tags --abbrev=0)..HEAD`, `git diff <last tag> -- lib`) against the invariants in CLAUDE.md, especially cache-key stability, the Hive schema and the public API.

## 3. Pick the version
- Read `## [Unreleased]` in CHANGELOG.md. If it's empty, stop: nothing to release.
- Propose the bump: patch for fixes only, minor for new backward-compatible API, major for breaking changes (also update MIGRATION.md). Explain why, and let the user confirm or change it.

## 4. Create the release branch
- Give the user `git switch -c release/vX.Y.Z` (run it only if they ask). All release edits go on this branch, since `main` only accepts pull requests.

## 5. Apply release edits
- `pubspec.yaml`: set `version:`.
- CHANGELOG.md: rename `## [Unreleased]` to `## [X.Y.Z] - YYYY-Mon-DD` (e.g. `2025-Dec-16`, today's date), and add a fresh empty `## [Unreleased]` above it only if the user wants one.
- README: update any version in the install snippet (`dio_cache_plus: ^X.Y.Z`) if one is present.

## 6. Dry run
- `dart pub publish --dry-run`: the only acceptable warning is "checked-in files are modified" for the uncommitted release edits; anything else must be fixed. Check the file list contains no `CLAUDE.md`, `.claude/`, `build/`, `.dart_tool/`, `pubspec.lock` or IDE files.

## 7. Hand off
Publishing runs in GitHub Actions (`.github/workflows/publish.yml`): pushing a `vX.Y.Z` tag re-runs all checks, verifies the tag matches `pubspec.yaml`, is on `main` and has a CHANGELOG section, then waits for approval in the `pub.dev` environment before publishing. After pub.dev accepts the version, the GitHub Release is created automatically with that CHANGELOG section as its notes.

Show the diff of the release edits and give the user these steps, without running them:
1. Commit on the release branch with message `version X.Y.Z`.
2. `git push origin release/vX.Y.Z`, open a pull request into `main`, wait for the `verify` check, then merge it.
3. Update local `main`: `git switch main` and `git pull origin main`. Confirm `pubspec.yaml` on `main` says `X.Y.Z`.
4. Tag the merged commit on `main` (not the branch commit; squash and merge commits differ): `git tag vX.Y.Z` then `git push origin vX.Y.Z`.
5. Approve the "Publish to pub.dev" run in GitHub Actions (Review deployments). The GitHub Release appears once publishing succeeds; don't create it by hand.

Run any of these only when the user explicitly says to, one action at a time. Never run `dart pub publish` locally; releases go through the workflow.
