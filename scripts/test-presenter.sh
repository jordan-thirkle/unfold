#!/usr/bin/env bash
# Compile the actual app presenter/view alongside an executable test harness.
# A logged-in macOS graphical session is required. No automation permissions.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/unfold-presenter.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
swiftc -swift-version 6 -emit-library -emit-module -module-name UnfoldCore \
  "$ROOT"/Sources/UnfoldCore/*.swift \
  -emit-module-path "$TMP/UnfoldCore.swiftmodule" -o "$TMP/libUnfoldCore.dylib"
swiftc -swift-version 6 -parse-as-library -I "$TMP" -L "$TMP" -lUnfoldCore \
  -Xlinker -rpath -Xlinker "$TMP" \
  "$ROOT/Sources/UnfoldApp/OverlayPresenter.swift" \
  "$ROOT/Sources/UnfoldApp/OverlayWindow.swift" \
  "$ROOT/Sources/UnfoldApp/SnapshotFoldView.swift" \
  "$ROOT/Tests/PresenterChecks/PresenterChecks.swift" -o "$TMP/presenter-checks"
"$TMP/presenter-checks"
