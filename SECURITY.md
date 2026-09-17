# Security

## Permissions and screen contents

The original timed mask effect requires no capture permission. The experimental
**Snapshot perspective preview** and **Track lid angle** actions explicitly ask
for consent and require macOS Screen Recording permission. The feature is off
by default and tracking is not persisted across launches.

ScreenCaptureKit captures one display image per fold. Images remain in memory;
Unfold does not save or upload them. Cancellation discards pending results and
clears the layer texture. Capture has a five-second timeout, preview lasts four
seconds, and a tracking overlay has a thirty-second safety limit. macOS may show
its recording indicator. Ad-hoc rebuilds may require permission again.

Tracking uses the built-in display and HID lid-angle reports. It stops on sensor
read failure, lock, sleep, session resignation or display changes. There are no
private lock-screen window APIs and no sleep-prevention settings. This is an
experimental best-effort session guard, not a security boundary guaranteed by
macOS; lock/session notifications use undocumented notification names. Do not
use with sensitive content until real lock-transition testing has been completed.

## Other data

Settings are read/written under Application Support/ByJTT/Unfold. The app also
observes power/session events and binary lid state. It has no network client,
telemetry, clipboard access, Accessibility or Input Monitoring requirement.
Logs include operational status, not captured pixels. The click-through overlay
never takes keyboard focus. Input still reaches underlying apps during a fold.

## Reporting

Report issues at https://github.com/jordan-thirkle/unfold/issues. Do not attach
sensitive screenshots; include macOS version, hardware and reproduction steps.
