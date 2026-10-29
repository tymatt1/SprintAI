# Interface direction

SprintAI is a training instrument. Its primary visual reference is a track-meet results sheet: time is prominent, supporting measurements are subordinate, and actions sit near the information they affect.

## Visual system

- Barlow Condensed Medium for time and page titles; Barlow Regular, Medium, and SemiBold for reading, labels, and emphasis. Custom fonts scale with Dynamic Type. Four unmodified font files and both OFL notices are bundled locally.
- Warm paper (`#F6F3EC` approximately), deep green ink, muted gray-green, and the app’s green accent. Primary controls, brand lettering, timer numerals, and selected navigation use green. Rep colors remain user data rather than additional interface accents.
- Open sections grouped by whitespace. A rule is reserved for a table header, navigation boundary, or form field; cards, shadows, gradients, and decorative status shapes are absent.
- SF Symbols supply one consistent outline icon vocabulary. App-authored labels use the bundled fonts; OS-owned pickers, alerts, share sheets, keyboard, and video transport remain native.
- No animated entrance or scroll effects. Press feedback is local to interactive controls.

## Structure

The app icon uses two parallel track lanes to form an S, drawn in warm paper on the same forest green as primary controls. It has no lettering, shadows, or gradients. Dark and monochrome tinted variants share the geometry. The vector source is in `Docs/Brand/app-icon.svg`; `swift Scripts/generate_app_icon.swift` regenerates all three opaque 1024-pixel assets.

Timing gives the numeral and monitoring action priority. The recorded-times chart is always present, defaults to all saved times, and precedes the summary and results list. Summary data varies in scale rather than appearing in interchangeable tiles. Color and race callouts belong in a menu; deletion belongs beside the selected result.

Analysis gives footage the primary column on wide displays, with measurements in the narrower column. Before import, camera-side controls and import are the main content; technical constraints and filming instructions live in the recording guide. Export and replacement actions live in the clip menu.

Settings uses open, labeled fields. Server configuration remains optional, and information about sharing and measurement limitations is disclosed in expandable sections.

SwiftUI layouts adapt to measured available width and Dynamic Type, using unequal horizontal columns when space permits and a single reading order when it does not. This is a native iOS implementation; there is no CSS layer.

## Verification

The shipped layout was inspected on iPhone 18 Pro and iPad Pro 13-inch in portrait and landscape, including a four-record synthetic history and selected-record actions. Selection reserves the same action column for every result, so the time column does not move when a menu appears. Chart labels use explicit Barlow text, and the plot measures its available column width.

At the largest accessibility size, navigation changes to a horizontally scrollable text rail rather than wrapping labels or capping the user's font size. The normal text setting is restored after inspection. Root screens retain their state; explicit active-screen changes stop monitoring and pause playback/cancel feedback when leaving a workspace. No transition animation is applied.

The simulator build, ten hosted iOS tests (including font registration), ten core tests, and unsigned iPhone Release build pass. Physical-device ergonomics and a full VoiceOver audit remain follow-up validation in issue #5.
