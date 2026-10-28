# Validation

Validated locally on October 28, 2026 with Xcode 15.4 / iOS 17.5 simulator.

| Check | Result |
|---|---|
| Swift Package core regression tests | 6 passed |
| Python feedback gateway tests, with mocked provider calls | 6 passed |
| Hosted iOS integration tests on iPhone 15 | 6 passed |
| Simulator app build | Passed |
| Unsigned physical-device Release build | Passed |
| Common credential-pattern scan of staged source and publication history | Passed before publication |

## Automated coverage

Core tests cover debounced start/stop transitions, duration from sensor timestamps, immediate subsequent sprints, reset behavior, duplicate/out-of-order samples, degenerate joint geometry, and short-clip frame selection.

Gateway tests cover input validation, authorization before provider access, bounded request rate, response extraction contract, and upstream-error redaction. No live OpenAI calls or charges are made by the tests.

The hosted iOS tests load the actual bundled Core ML model, run inference with the expected input shape, initialize MediaPipe while processing a synthetic video, verify portrait export dimensions and playable frames, test cancellation, verify annotation orientation and visibility filtering, round-trip saved record colors including legacy grayscale, and preserve unreadable history in a recovery copy.

## Manual smoke checks

The app launches in the iPhone 15 simulator. Timing controls and tabs render; starting motion monitoring shows a clear unavailable-sensors message and returns to the stopped state. Analysis import entry and feedback Settings screens render. Screenshots are included in this repository.

## Remaining validation

These checks do not establish real-world sprint timing accuracy or biomechanical validity. Before distributing an updated app, test:

- Real athletes, phone placements, sensor availability/permission failures, and interrupted recordings.
- Timing error against an independent reference and preprocessing consistency with training.
- Real sprint videos across landscape/portrait, slow motion, different frame rates, occlusion, and left/right camera placement.
- Photos permission denial, successful save/export, iCloud downloads, and large-file memory use.
- Configured HTTPS backend authentication, real provider responses, cancellation, and cost/retention controls using a new server-side key.
- The oldest supported iPhone, iPad multitasking/orientation, larger text sizes, and VoiceOver.

No hosted feedback service is deployed, and no new API credentials are provisioned. GitHub Actions configuration is included; its hosted results should be checked after publication.
