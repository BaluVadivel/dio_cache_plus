---
name: release
description: Prepare a dio_cache_plus release to pub.dev - sync check, tests, version bump, CHANGELOG, publish dry run. Stops before any git or publish action.
disable-model-invocation: true
---

# Release dio_cache_plus

Prepare the release, then stop. Never stage, commit, tag, push or publish unless the user explicitly asks for that specific action. Approval for one doesn't cover the next.

## 1. Make sure we're releasing from the latest code
- Run `git fetch origin` (only updates remote-tracking refs), then `git status -sb`. If `main` is behind or has diverged from `origin/main`, stop and tell the user. Releasing from stale code would undo published changes.
- Check the latest published version: `curl -s https://pub.dev/api/packages/dio_cache_plus | python3 -c "import json,sys; print(json.load(sys.stdin)['latest']['version'])"`. If it's newer than `version:` in `pubspec.yaml`, stop and tell the user.
- The working tree must be clean apart from release edits. If not, list what's uncommitted and ask whether it belongs in this release.

## 2. Verify quality
- `flutter analyze`: no issues.
- `flutter test`: all pass. Report failures with output; don't continue past them.
- `dart format --output=none --set-exit-if-changed lib test`: report unformatted files.
- Review the changes since the last tag (`git log $(git describe --tags --abbrev=0)..HEAD`, `git diff <last tag> -- lib`) against the invariants in CLAUDE.md, especially cache-key stability, the Hive schema and the public API.

## 3. Pick the version
- Read `## [Unreleased]` in CHANGELOG.md. If it's empty, stop: nothing to release.
- Propose the bump: patch for fixes only, minor for new backward-compatible API, major for breaking changes (also update MIGRATION.md). Explain why, and let the user confirm or change it.

## 4. Apply release edits
- `pubspec.yaml`: set `version:`.
- CHANGELOG.md: rename `## [Unreleased]` to `## [X.Y.Z] - YYYY-Mon-DD` (e.g. `2025-Dec-16`, today's date), and add a fresh empty `## [Unreleased]` above it only if the user wants one.
- README: update any version in the install snippet (`dio_cache_plus: ^X.Y.Z`) if one is present.

## 5. Dry run
- `dart pub publish --dry-run`: must show 0 warnings. Check the file list contains no `CLAUDE.md`, `.claude/`, `build/`, `.dart_tool/`, `pubspec.lock` or IDE files.

## 6. Hand off
Publishing runs in GitHub Actions (`.github/workflows/publish.yml`): pushing a `vX.Y.Z` tag re-runs all checks, verifies the tag matches `pubspec.yaml` and is on `main`, then waits for approval in the `pub.dev` environment before publishing.

Show the diff of the release edits and give the user, without running them:
- commit message: `version X.Y.Z`
- `git push origin main`, then wait for CI to pass on main
- `git tag vX.Y.Z` and `git push origin vX.Y.Z`
- approve the "Publish to pub.dev" run in GitHub Actions

Run any of these only when the user explicitly says to, one action at a time. Never run `dart pub publish` locally; releases go through the workflow.
