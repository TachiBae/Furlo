# Implementation Plan: Fix "saving a pet" failure

## Problem
Adding a pet from the dashboard shows **"Could not save your pet. Please try again."** even though the form is valid. (Confirmed by reproduction in `test/save_pet_repro_test.dart`.)

## Root cause (confirmed)
During the auth-gate refactor, `ChangeNotifierProvider<FurloState>` was moved from **above** `MaterialApp` (original `_FurloAppState.build`) to **inside** the `home` widget (`_AuthGate.build`).

In Flutter, routes pushed onto the `Navigator` are siblings of the `home` route within the `Navigator`'s overlay. A provider defined inside `home` is therefore **not an ancestor** of pushed routes. So when `AddPetScreen` is opened from `HomeScreen._addPet()` (a pushed route), `context.read<FurloState>()` in `_savePet` throws `ProviderNotFoundException`, which the `catch` reports as the generic "Could not save your pet" message.

This is broader than Add Pet: every pushed screen that reads `FurloState` is affected (`PetProfileScreen`, `FeedingScreen`, `VetContactsScreen`), and so is the `pushAndRemoveUntil(HomeScreen(...))` at the end of `_savePet` (the new `HomeScreen` is a fresh route outside the provider). The first-pet flow happens to work only because there `AddPetScreen` is the `home` widget (inside the provider) and it relies on a rebuild rather than navigation.

A minimal reproduction proved the scoping rule directly: a route pushed from `home` cannot read a provider defined inside `home`.

## Fix
Restore `FurloState` visibility to **all** routes by providing it above the `Navigator`, without disturbing the working `home` path:

1. In `_FurloAppState`, hold the current `FurloState?` and expose a callback to receive it from `_AuthGate`'s session lifecycle.
2. In `MaterialApp.builder` (composed with the existing `DevicePreview.appBuilder`), wrap the Navigator `child` with `ChangeNotifierProvider<FurloState>.value` when a `FurloState` exists. A provider placed here is an ancestor of every route (home and pushed).
3. Wire `_AuthGate`/`_AuthGateState` to report the active `FurloState` up when a session starts and report `null` on session reset (before disposing the old state).
4. Keep the existing `ChangeNotifierProvider` inside `_AuthGate.build` so the `home`/first-pet path is unchanged.

No screen call-sites change; `context.read/watch<FurloState>()` works everywhere again.

## Files to change
- `lib/app.dart` — hoist `FurloState` reference to `_FurloAppState`, add the above-`Navigator` provider in `MaterialApp.builder`, wire the callback through `_AuthGate`.
- `test/save_pet_repro_test.dart` — turn into a proper regression test: keep the "save pet from dashboard" case (must pass after fix); remove the throwaway provider-semantics diagnostic.

## Tests
- Regression: saving a pet from the dashboard adds the pet and returns to the dashboard with **no** error, and the pet list reflects the new pet.
- Existing first-pet routing tests in `test/auth_gate_test.dart` must still pass (home path unchanged).
- Full `flutter test` must pass.

## Verification
- `dart format` on touched files.
- `flutter analyze` clean.
- Focused tests, then full `flutter test`.
- Run `flutter run -d web-server` and, if a signed-in session is available, verify Add Pet at 375px/1440px; otherwise report the limitation.

## Safety / scope
- No destructive migrations, no Firebase operations, no commits/push, no new dependencies.
- Preserve unrelated dirty worktree changes.
