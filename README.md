# Unfold

**Your Mac unfolds when you open it.**

Unfold is a small macOS menu bar app. Pick an animation, set the speed, leave it
running: when the machine wakes, the desktop is revealed by a fold that opens
from the hinge instead of just appearing.

It is a menu bar agent — no Dock icon, no window, nothing to close.

## What it actually does, and what it can't

Worth stating plainly before you install it, because the honest version of this
idea is narrower than the pitch:

| Moment | Behaviour |
|---|---|
| **Wake from sleep** | The fold plays the instant your session becomes active and the desktop appears. |
| **Unlock** (password required) | The fold plays the moment you unlock. |
| **Lid close** | Best-effort. macOS begins clamshell sleep almost immediately, so the closing fold is short by design and may not finish. |

**It cannot draw on the password screen.** That surface belongs to
`loginwindow`, which runs as root in a separate session, so a normal app cannot
draw there. Replacing the login screen wallpaper is a System Integrity
Protected path, which means it is not something this app can or will do. The
effect is therefore *"my desktop unfolds when I get in"*, not *"my password
prompt folds"*.

## Install

Requires macOS 14 or later.

```bash
git clone https://github.com/jordan-thirkle/unfold.git
cd unfold
./scripts/build-app.sh
open build/Unfold.app
```

Unfold appears in the menu bar. Choose **Start at login** so it is there after a
restart.

Nothing is sent anywhere. There is no network code in this repository at all.

> **Distribution note.** The build script signs ad-hoc, which is fine on your
> own Mac. Giving the app to other people needs a Developer ID certificate and
> notarisation (Apple Developer Program, $99/year) — otherwise Gatekeeper warns
> them. Source builds are free and always work.

## Configure

Everything lives in the menu bar item:

- **Animate when the Mac wakes** — the main animation.
- **Animate when the lid closes** — best-effort, see above.
- **Respect Reduce Motion** — when on, Reduce Motion means *no animation*
  rather than a faster one.
- **Animation** — Unfold, Lid, Iris, Quiet.
- **Opening speed** — 0.6s to 1.6s.
- **Closing speed** — 0.25s to 0.6s, deliberately short.
- **Preview animation** — play it now, so you can tune it without sleeping your
  Mac.
- **Start at login** — via `SMAppService`.

Settings are written to
`~/Library/Application Support/ByJTT/Unfold/config.json`. If that file is ever
unreadable the app says so in the menu and falls back to defaults rather than
failing silently.

## Verify

```bash
swift run unfold-verify
```

19 checks over the deterministic core, exiting non-zero on failure.

### Why not just `swift test`

XCTest was removed from the Command Line Tools in CLT 26.x. Swift Testing's
macros still work, but SPM's generated test runner falls back to the `xctest`
path unless told otherwise, and that path is compiled out — so on a CLT-only
machine `swift test` **builds the bundle and exits 0 without running a single
test**. A green `swift test` there means nothing.

That is exactly why the checks live in `UnfoldChecks` as framework-free
functions. `swift run unfold-verify` always executes, and the `swift test`
suites in `Tests/` are thin wrappers that call the same functions, so the two
cannot drift apart. (It is also how the first real bug got caught: a
zero-duration fold never announced that it had finished.)

## Architecture

```
Sources/
  UnfoldCore/     deterministic simulation — no AppKit, no I/O, no globals
  UnfoldChecks/   framework-free assertions over UnfoldCore
  unfold-verify/  runs those checks
  UnfoldApp/      the menu bar agent: system events + overlay rendering
Tests/
  UnfoldCoreTests/  Swift Testing wrappers over UnfoldChecks
```

Two ideas do the real work:

**Simulation is separate from rendering.** `FoldSimulation` advances in fixed
steps and accumulates time as *integer nanoseconds*, so the state after N
seconds never depends on how those seconds were delivered. One 0.5s delta and
fifty 0.01s deltas reach byte-identical state. Rendering reads a `FoldState`
value and draws it; it makes no timing decisions. That is what makes the fold
testable without a display.

**Events are the communication layer.** The simulation emits
`started` / `ticked` / `finished`; the overlay, the menu bar and any future
audio work consume those instead of reading the simulation's internals.

Adding an animation means describing it in `AnimationPreset` — axis, easing,
fade — not touching the renderer.

### Platform constraints found during the build

Recorded here because they shaped the product and because they are easy to
rediscover the hard way:

- `NSWorkspace` publishes wake, sleep, screen and session notifications, but
  **no lock or unlock notification**. Lock/unlock comes from the undocumented
  distributed notifications `com.apple.screenIsLocked` /
  `com.apple.screenIsUnlocked`.
- The lid is read from the IOKit registry key `AppleClamshellState` (polled, not
  pushed).
- Reducing the closing animation's duration is not a style choice: closing the
  lid sleeps the Mac before a long animation could finish, and `caffeinate(8)`
  notes that the assertion which prevents system sleep *"is valid only when
  system is running on AC power"*.

## Status

v0.1.0 — early. It works; it is not yet packaged for anyone but you.

## License

MIT. See [LICENSE](LICENSE).
