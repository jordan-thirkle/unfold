# Security

## What this app can see

Unfold observes system events only:

- power state — wake, sleep, screen sleep/wake
- session state — login, fast user switching, lock/unlock
- lid state, read from the IOKit registry key `AppleClamshellState`

It draws a borderless, click-through, non-key window above the desktop for the
duration of the animation, then removes it.

## What this app cannot do

- It has **no network code**. There is no HTTP client, no telemetry, no
  analytics, no update check anywhere in this repository.
- It does not request Accessibility, Screen Recording, or Input Monitoring
  permissions, and it does not work by synthesising input.
- It does not read your files, keychain, clipboard, or window contents.
- It cannot draw on the login screen. It does not attempt to.

## Permissions

None are required. If a future version needs one, it will be documented here
before the release that needs it, not after.

## Reporting a problem

Open an issue at
<https://github.com/jordan-thirkle/unfold/issues>. If the report is sensitive,
say so in the issue and a private channel will be arranged rather than asking
you to post details publicly.

Please include your macOS version, whether the app was built from source or
downloaded, and the exact steps that triggered the problem.
