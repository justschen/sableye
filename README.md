# Sableye 💎

A native macOS note-taking app whose window is **invisible to screen sharing and
screen recording** (Microsoft Teams, Zoom, QuickTime, OBS, etc.) — while staying
fully visible to you on your own display. Like its namesake lurking in the dark,
your notes stay hidden from prying captures.

## Quick start

You only need a Mac. Clone the repo and run one command:

```bash
git clone <your-repo-url> sableye
cd sableye
./run.sh
```

`run.sh` checks the toolchain, builds the app, and launches it. The first run
takes a few seconds to compile; after that it relaunches instantly.

> **Dependency:** the build uses Apple's Swift compiler (`swiftc`), which ships
> with the **Xcode Command Line Tools**. If they're missing, `run.sh` kicks off
> the installer for you (`xcode-select --install`) — accept the macOS dialog,
> then run `./run.sh` again. No Xcode app or other downloads required.

Because you build it yourself, there's **no Gatekeeper "unidentified developer"
warning** — that only happens when downloading a prebuilt app.

## How it works

The app sets the window's `NSWindow.sharingType = .none`. macOS then excludes the
window from the screen-capture pipeline (**ScreenCaptureKit**, which is what Teams
uses on modern macOS). Anything captured/shared shows whatever is *behind* the
notes window, not the notes themselves.

Verified mechanism: the window reports `kCGWindowSharingState == 0` (None), which
is the exact flag capture tools honor to skip a window.

## Scripts

| Script | What it does |
| --- | --- |
| `./run.sh` | Build (if needed) and launch the app. **Start here.** |
| `./build.sh` | Compile `Sources/main.swift` into `Sableye.app` (universal arm64 + x86_64) and generate the app icon from `Resources/AppIcon.svg`. |
| `./package.sh` | Build, then zip the app into `Sableye.zip` for sharing a prebuilt binary. |

This compiles `Sources/main.swift` into `Sableye.app` (no Xcode required).
The build produces a **universal binary**, so it runs on both Apple Silicon and
Intel Macs.

## Share a prebuilt copy

If you'd rather send someone the built app instead of having them clone and build:

```bash
./package.sh
```

This builds the app and produces `Sableye.zip` (using `ditto`, which
preserves the bundle and its code signature).

**The recipient** unzips it and moves `Sableye.app` to `/Applications` (or
anywhere). Because the app is only **ad-hoc signed** (not signed with a paid
Apple Developer ID), macOS Gatekeeper blocks it on first launch after download
with *"Apple could not verify 'Sableye' is free of malware."* They clear it
one time with either:

- **Terminal (most reliable):**
  `xattr -dr com.apple.quarantine /path/to/Sableye.app`
  — then double-click the app.
- **No Terminal:** click **Done** (not *Move to Trash*) on the warning, then open
  **System Settings ▸ Privacy & Security**, scroll down to *"Sableye was
  blocked…"*, and click **Open Anyway**.

(On older macOS you could right-click ▸ Open instead; on current macOS use one of
the two methods above. To distribute with no warning at all you'd need an Apple
Developer ID signature plus notarization.)

## Run

After the first build, relaunch any time with either:

```bash
./run.sh           # rebuilds only if the source changed, then launches
open ./Sableye.app
```

## Using it

- Type notes in the editor — they auto-save to
  `~/Library/Application Support/Sableye/notes.txt`.
- **Edit / Preview** toggle (top-left segmented control) — switch between the raw
  Markdown editor and a rendered Markdown preview. `Cmd+Shift+P` also toggles it.
- **Hide** switch — toggles capture invisibility (on by default).
  `Cmd+Shift+H` also toggles it.
- **Top** switch — keeps the window floating above other apps; it also follows
  you across Spaces and over fullscreen apps.
- **Opacity** slider — dim the window if you like.
- `Cmd+Q` to quit (notes are saved on quit too).

## Important caveats (please read)

- This hides the window from **digital screen capture only**. A phone photo of your
  screen, or someone physically looking over your shoulder, will still see it.
- It works when you share your **whole screen** or **another app's window**. Do not
  share the *Sableye* window itself — that would obviously show it.
- Relies on Apple's `sharingType` API. It is the same technique used by overlay/
  privacy apps and works on current macOS, but Apple could change capture behavior
  in future OS versions — test once after any major macOS update (toggle the
  checkbox off, confirm it appears in a test recording, toggle back on).

## Quick self-test

1. Start a screen recording (QuickTime ▸ File ▸ New Screen Recording) or a Teams
   test share of your whole screen.
2. With **Hide from screen share** ON, the note window should be absent from the
   capture. Toggle it OFF and it reappears.
