# Implementation Plan: Resolve analyzer findings under generated build trees

## Goal
Make `flutter analyze` stop treating vendored/generated package sources under `furlo/build/ios` and `furlo/build/macos` as application source, without modifying those generated trees or changing app code.

## Findings so far
- The current branch is `feature/accounts`.
- `build/` is ignored; its iOS/macOS `SourcePackages` contain generated Firebase Auth and Cloud Firestore package checkouts.
- The observed analyzer report contains package/example/test diagnostics under those generated paths, rather than diagnostics in project `lib/` or `test/` files.
- The existing `analysis_options.yaml` does not configure analyzer exclusions.
- The analyzer run also caused generated plugin registrant changes outside the requested build subtrees; those are existing/unrelated working-tree changes and must not be overwritten.

## Proposed change (pending approval)
Add precise `analyzer.exclude` globs to `furlo/analysis_options.yaml` for the generated build subtrees `build/ios/**` and `build/macos/**`. Do not edit or delete anything under `build/`, do not run `flutter clean`, and do not change application or platform files.

## Verification after approval
1. Run `flutter analyze` from `furlo` and inspect its complete result.
2. Run `dart analyze` on the auth-related files and `flutter test` if analyzer configuration changes affect analysis scope; do not alter tests or suppress source diagnostics.
3. Verify final status and diff: only the analyzer configuration should be newly changed by this repair; preserve all pre-existing modifications.

## Constraint
No edits are made until approval, per the project workflow.