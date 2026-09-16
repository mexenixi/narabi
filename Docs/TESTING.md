# Testing

This document records the latest verified baseline and the remaining manual checks. It is a verification record, not a claim that every device, input file, or operating condition is covered.

## Latest Verified Baseline

- Source baseline: Narabi version 1.0 public source baseline
- Automated unit tests: **224 passed**
- Release configuration build: succeeded
- Test bundles inside the Release app: **0**
- `NarabiTests` files inside the Release app: **0**
- Repository audit: **0 errors, 0 warnings**
- Architecture audit: **0 errors, 0 warnings**
- Document-import safety audit: **0 errors**

The baseline above was verified locally before this documentation and CI update. Future results should record the tested commit and date instead of silently replacing historical context.

## Automated Verification

GitHub Actions contains three independent jobs:

1. `repository-audit` runs `Scripts/audit_all.sh` on Ubuntu.
2. `unit-tests` runs the complete `NarabiTests` target on a macOS iPhone Simulator with code signing disabled.
3. `ui-smoke-tests`: runs the dedicated Narabi UI smoke-test target on an iPhone simulator.

The macOS job verifies core logic but does not replace physical-device checks for drag behavior, system pickers, printing, sharing, memory pressure, or accessibility.

## Local Unit-Test Command

```bash
xcodebuild test \
  -project Narabi.xcodeproj \
  -scheme Narabi \
  -destination "platform=iOS Simulator,id=<available-iPhone-simulator-UDID>" \
  -only-testing:NarabiTests \
  CODE_SIGNING_ALLOWED=NO
```

## Release Verification

Release verification must confirm all of the following:

- the app builds successfully in Release configuration;
- newly extracted production files are compiled into the app target;
- no `.xctest` bundle is present inside the produced app;
- no file from `NarabiTests` is copied into the produced app;
- repository, architecture, and document-import safety audits pass.

## Physical-Device and Workflow Checks

The following checks remain physical-device or manual responsibilities:

- mixed photo, image, scanned-document, and PDF import;
- approximately 100 mixed photographs and screenshots without a crash;
- reordering, multi-selection, tray movement, scrolling, and drag cancellation;
- page crop, rotation, document correction, composite editing, save, and cancel;
- PDF, JPEG, PNG, Photos, print preview, and system share-sheet output;
- project persistence, backup recovery, deletion, and restoration;
- Dynamic Type, VoiceOver labels, non-color state cues, and orientation changes;
- iPad Split View or Stage Manager width changes.

## New Project Preparation Progress

- Confirm that progress appears after **Edit these items** and before the editor opens.
- Confirm that page progress increases monotonically to the total for multiple images and multi-page PDFs.
- Confirm that repeated taps cannot create duplicate projects.
- Confirm that project saving completes before navigation.
- Confirm that VoiceOver announces progress labels and values.

## Export Temporary-File Lifetime

- Print a one-page JPEG through the system share sheet and confirm that the destination can still read the file after the share sheet closes.
- Confirm that a later launch removes only Narabi-owned export directories and `NarabiAIFiles` after they are at least 24 hours old.
- Confirm that arbitrary temporary PDF, JPEG, and PNG files are not classified as Narabi-owned by extension alone.

## UI Smoke Tests

Narabi includes a dedicated `NarabiUITests` target and a shared `Narabi` scheme that runs both unit tests and UI tests.

The initial smoke suite verifies the following app-owned routes in English and Japanese:

- app launch and home screen availability
- opening and closing App Settings
- opening the new-project import screen and returning home

The tests use stable accessibility identifiers rather than localized visible text:

- `home.newProject`
- `home.settings`
- `settings.done`
- `import.back`

System-owned interfaces such as Photos Picker, document picker, and the share sheet are intentionally excluded from the initial smoke suite because their availability and presentation are controlled by iOS. Those flows remain part of device verification.

GitHub Actions runs the UI smoke suite in a separate macOS job. Local verification runs the existing 224 unit tests and the two UI smoke tests together before release verification.

## StoreKit Support Purchase Verification

- Three optional support products use lowercase, fixed Product IDs.
- All three products are consumable and do not change editing features, storage capacity, usage restrictions, or support priority. A randomized thank-you message and its received date are stored locally after purchase.
- Xcode StoreKit Testing uses `StoreKit/Narabi.storekit` before Sandbox testing.
- Automated tests verify catalog IDs and purchase-state gating.
- Manual verification remains required for successful purchase, cancellation, pending approval, repeated consumable purchase, and the post-purchase thank-you message.
- Sandbox and TestFlight verification are recorded only after using App Store Connect product data.
