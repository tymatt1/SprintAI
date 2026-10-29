# Validation

Validated locally on October 28, 2026 with Xcode 27.0 / iOS 27.0 simulator for the October 28 polish updates.

| Check | Result |
|---|---|
| Swift Package core regression tests | 10 passed |
| Python feedback gateway tests, with mocked provider calls | 6 passed |
| Hosted iOS integration tests on iPhone 18 Pro, MediaPipe 1.0.0 | 10 passed |
| Simulator app build | Passed |
| Unsigned physical-device Release build | Passed with MediaPipe 1.0.0 |
| Common credential-pattern scan of staged source and publication history | Passed before publication |

## Automated coverage

Core tests cover debounced start/stop transitions, duration from sensor timestamps, immediate subsequent sprints, reset behavior, duplicate/out-of-order samples, degenerate joint geometry, short-clip frame selection, interpolated 50 Hz sample cadence, sensor-gap resets, first-decision boundaries, and nearest playback measurements across seeks and pose gaps.

Gateway tests cover input validation, authorization before provider access, bounded request rate, response extraction contract, and upstream-error redaction. No live OpenAI calls or charges are made by the tests.

A hosted font-registration test verifies that all four bundled Barlow typefaces are available through UIFont rather than relying on a system fallback. The hosted iOS tests load the actual bundled Core ML model, run inference with the expected input shape, initialize MediaPipe while processing a synthetic video, verify portrait export dimensions and playable frames, test cancellation, verify annotation orientation, both analysis sides, out-of-frame rejection, and visibility filtering, round-trip saved record colors including legacy grayscale, preserve unreadable or invalid-duration history in a recovery copy, and expose older records through all-time history. A one-second synthetic video verifies distinct, chronologically ordered, bounded coaching frames without making a provider request. The frame regression failed before precise extraction/deduplication was added and passed afterward.

## Manual smoke checks

The typography-led redesign launches in the iPhone 18 Pro simulator. The open timing workspace, video import, settings, and custom navigation render; starting motion monitoring shows a clear unavailable-sensors message and returns to the stopped state. Camera-side selection, filming guidance, explicit import, and feedback Settings screens render. The iPad Pro 13-inch portrait/landscape layout and populated results selection were also inspected. The largest accessibility text size uses a horizontal text navigation rail; headings wrap and the workspace scrolls without reducing the requested font size. Normal text size was restored after verification. Updated screenshots are included in this repository; tablet history uses explicitly synthetic demo records in an isolated simulator, with original preferences backed up before seeding.

## Validation limits

The first local iOS test invocation passed all assertions but spent ten minutes collecting simulator diagnostics after a runtime priority-inversion warning. The earlier nine-test run and subsequent ten-test redesign runs used `-collect-test-diagnostics never` and completed successfully; this disables extra failure diagnostics, not assertions. No athlete footage or calibrated reference measurements were used.

## Remaining validation

These checks do not establish real-world sprint timing accuracy or biomechanical validity. Before distributing an updated app, test:

- Real athletes, phone placements, sensor availability/permission failures, and interrupted recordings.
- Timing error against an independent reference and preprocessing consistency with training.
- Real sprint videos across landscape/portrait, slow motion, different frame rates, occlusion, and left/right camera placement.
- Photos permission denial, successful save/export, iCloud downloads, and large-file memory use.
- Configured HTTPS backend authentication, real provider responses, cancellation, and cost/retention controls using a new server-side key.
- The oldest supported iPhone, iPad multitasking/orientation, larger text sizes, and VoiceOver.

No hosted feedback service is deployed, and no new API credentials are provisioned. GitHub Actions configuration is included; its hosted results should be checked after publication.

## Green-theme follow-up

The green accent, subtitle removal, and always-visible recorded-times chart were checked with one simulator build and a brief phone/tablet review. The chart now appears before summaries, including its empty state, and defaults to all saved records. Existing per-record colors remain intact; the tablet screenshot uses the existing synthetic demonstration history. Full test suites were not rerun for this requested UI refinement.

## Physical-device signing

The legacy app identifier was rejected by the selected Personal Team. With `com.tymatt1.SprintAI`, Xcode successfully created a managed profile, signed the Debug build, and installed it on the connected iPhone 17. The first launch was blocked by the iPhone's developer-certificate trust setting; a successful app launch has not yet been verified. The selected signing team remains a local Xcode setting and is not published.

## Icon and timing-boundary follow-up

All 15 core tests pass, including new fixtures for score-crossing interpolation, separate acceleration/model gate crossings, dropout recovery, reset/gap handling, and invalid/out-of-order decisions. A signed generic-iOS Debug build passes with the new standard, dark, and tinted icon assets; `codesign --verify --deep --strict` also passes. The icon geometry was visually inspected and the 1024-pixel PNGs are opaque. Full iOS integration and backend suites were not rerun for these focused changes.

These fixtures establish threshold arithmetic and confirmation behavior, not improved athlete timing accuracy. No new reference-timed athlete measurements were collected. The connected iPhone later became unavailable to the device service, so the updated build's on-device launch is not claimed.
