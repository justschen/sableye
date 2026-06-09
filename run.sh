#!/bin/bash
# One command to build (if needed) and launch Sableye.
# Checks the toolchain, compiles Sources/main.swift, then opens the app.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Sableye"
BUNDLE="${APP_NAME}.app"
BIN="$BUNDLE/Contents/MacOS/$APP_NAME"

# --- 1. Platform check ---------------------------------------------------
if [ "$(uname)" != "Darwin" ]; then
    echo "Error: Sableye is a macOS app and only runs on macOS." >&2
    exit 1
fi

# --- 2. Toolchain check --------------------------------------------------
# swiftc ships with the Xcode Command Line Tools — the only dependency.
if ! command -v swiftc >/dev/null 2>&1; then
    echo "==> Swift compiler not found."
    echo "    Installing the Xcode Command Line Tools (a system dialog will open)..."
    xcode-select --install 2>/dev/null || true
    echo
    echo "    Finish that installation, then run ./run.sh again."
    exit 1
fi

# --- 3. Build only when needed -------------------------------------------
if [ ! -x "$BIN" ] || [ Sources/main.swift -nt "$BIN" ] || [ build.sh -nt "$BIN" ] || [ Resources/AppIcon.svg -nt "$BIN" ]; then
    echo "==> Building $BUNDLE"
    ./build.sh
else
    echo "==> $BUNDLE is up to date"
fi

# --- 4. Launch -----------------------------------------------------------
echo "==> Launching $BUNDLE"
open "$BUNDLE"
