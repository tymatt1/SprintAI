# Interface direction

SprintAI is a training instrument. Its primary visual reference is a track-meet results sheet: time is prominent, supporting measurements are subordinate, and actions sit near the information they affect.

## Visual system

- Barlow Condensed Medium for time and page titles; Barlow Regular, Medium, and SemiBold for reading, labels, and emphasis. Custom fonts scale with Dynamic Type. Four unmodified font files and both OFL notices are bundled locally.
- Warm paper (`#F6F3EC` approximately), near-black ink, muted gray, and a vermilion signal color. Rep colors remain user data rather than additional interface accents.
- Open sections grouped by whitespace. A rule is reserved for a table header, navigation boundary, or form field; cards, shadows, gradients, and decorative status shapes are absent.
- SF Symbols supply one consistent outline icon vocabulary. App-authored labels use the bundled fonts; OS-owned pickers, alerts, share sheets, keyboard, and video transport remain native.
- No animated entrance or scroll effects. Press feedback is local to interactive controls.

## Structure

Timing gives the numeral and monitoring action priority. Summary data varies in scale rather than appearing in interchangeable tiles. History reads as a results list. Color and race callouts belong in a menu; deletion belongs beside the selected result.

Analysis gives footage the primary column on wide displays, with measurements in the narrower column. Before import, concise technical constraints and filming instructions replace an illustration or promotional hero. Export and replacement actions live in the clip menu.

Settings uses open, labeled fields. Server configuration remains optional, and information about sharing and measurement limitations is disclosed in expandable sections.

SwiftUI layouts adapt to measured available width and Dynamic Type, using unequal horizontal columns when space permits and a single reading order when it does not. This is a native iOS implementation; there is no CSS layer.
