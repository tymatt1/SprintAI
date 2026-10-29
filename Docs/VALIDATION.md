# Validation

Validated locally on October 28, 2026 with Xcode 27.0 / iOS 27.0 simulator for the October 28 polish updates.

| Check | Result |
|---|---|
| Swift Package core regression tests | 10 passed |
| Python feedback gateway tests, with mocked provider calls | 6 passed |
| Hosted iOS integration tests on iPhone 18 Pro, MediaPipe 1.0.0 | 9 passed |
| Simulator app build | Passed |
| Unsigned physical-device Release build | Passed with MediaPipe 1.0.0 |
| Common credential-pattern scan of staged source and publication history | Passed before publication |

## Automated coverage

Core tests cover debounced start/stop transitions, duration from sensor timestamps, immediate subsequent sprints, reset behavior, duplicate/out-of-order samples, degenerate joint geometry, short-clip frame selection, interpolated 50 Hz sample cadence, sensor-gap resets, first-decision boundaries, and nearest playback measurements across seeks and pose gaps.

Gateway tests cover input validation, authorization before provider access, bounded request rate, response extraction contract, and upstream-error redaction. No live OpenAI calls or charges are made by the tests.

The hosted iOS tests load the actual bundled Core ML model, run inference with the expected input shape, initialize MediaPipe while processing a synthetic video, verify portrait export dimensions and playable frames, test cancellation, verify annotation orientation, both analysis sides, out-of-frame rejection, and visibility filtering, round-trip saved record colors including legacy grayscale, preserve unreadable or invalid-duration history in a recovery copy, and expose older records through all-time history. A one-second synthetic video verifies distinct, chronologically ordered, bounded coaching frames without making a provider request. The frame regression failed before precise extraction/deduplication was added and passed afterward.

## Manual smoke checks

The refreshed app launches in the iPhone 18 Pro simulator. The timer dashboard, video import, settings, and tabs render; starting motion monitoring shows a clear unavailable-sensors message and returns to the stopped state. Camera-side selection, filming guidance, explicit import, and feedback Settings screens render. Updated screenshots are included in this repository.

## Validation limits

The first local iOS test invocation passed all assertions but spent ten minutes collecting simulator diagnostics after a runtime priority-inversion warning. The final nine-test run used `-collect-test-diagnostics never` and completed successfully; this disables extra failure diagnostics, not assertions. No athlete footage or calibrated reference measurements were used.

## Remaining validation

These checks do not establish real-world sprint timing accuracy or biomechanical validity. Before distributing an updated app, test:

- Real athletes, phone placements, sensor availability/permission failures, and interrupted recordings.
- Timing error against an independent reference and preprocessing consistency with training.
- Real sprint videos across landscape/portrait, slow motion, different frame rates, occlusion, and left/right camera placement.
- Photos permission denial, successful save/export, iCloud downloads, and large-file memory use.
- Configured HTTPS backend authentication, real provider responses, cancellation, and cost/retention controls using a new server-side key.
- The oldest supported iPhone, iPad multitasking/orientation, larger text sizes, and VoiceOver.

No hosted feedback service is deployed, and no new API credentials are provisioned. GitHub Actions configuration is included; its hosted results should be checked after publication.
