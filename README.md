# DeXmac

DeX-style Android app windows on macOS, for Galaxy phones that can't run DeX on a
virtual display.

A thin wrapper around [scrcpy](https://github.com/Genymobile/scrcpy) that opens each
Android app in its own resizable virtual display, rendered as a normal Mac window.
The apps run on the phone's own hardware — nothing is emulated.

---

## Why this exists

Samsung ended DeX for macOS in January 2022, then dropped DeX for PC entirely with
One UI 7. In One UI 8 DeX was rebuilt on Android's native Desktop Mode and can run on
any virtual display, which means scrcpy alone gives you the real DeX desktop on a Mac:

```bash
scrcpy --new-display=1920x1080/240 --flex-display
```

**If your phone is on One UI 8 (Android 16) or later, use that command and stop
reading — you don't need this script.**

Below One UI 8, classic DeX only activates on a physical external display. There is
no flag, setting or intent that will put it on a virtual one. DeXMac is the fallback:
instead of one DeX desktop, you get one window per app, which covers most of what DeX
was actually useful for.

## Requirements

| | |
|---|---|
| macOS | Intel or Apple Silicon |
| scrcpy | 4.0 or later (`--flex-display` was added in 4.0) |
| adb | any recent platform-tools |
| Phone | Android 8+ for virtual displays; USB debugging enabled |

Both `scrcpy` and `adb` are picked up from the script's own directory if present,
otherwise from `PATH`. If you're using a portable scrcpy build, keep `dexmac.sh`
next to the `scrcpy` binary and `scrcpy-server` — the script sets
`SCRCPY_SERVER_PATH` for you.

Homebrew install instead:

```bash
brew install scrcpy
brew install --cask android-platform-tools   # only if `which adb` is empty
```

## Setup

```bash
chmod +x dexmac.sh
./dexmac.sh setup
```

`setup` enables freeform windows and forced-resizable activities on the device. It
writes three global settings and persists across reboots. Reboot the phone if apps
still refuse to resize.

## Commands

```
./dexmac.sh setup                 one-time device configuration
./dexmac.sh apps                  list installed packages
./dexmac.sh run <pkg|Name>        open an app in its own window
./dexmac.sh big <pkg|Name>        same, at 2560x1440
./dexmac.sh blank                 empty virtual display
./dexmac.sh export <pkg> <Name>   write a double-clickable .command launcher
./dexmac.sh overlay on|off        legacy overlay-display experiment
./dexmac.sh doctor                device, display and version state
```

### App names vs package names

`run` and `big` accept either. A bare word with no dot is treated as an app *name* and
gets scrcpy's `?` prefix added automatically:

```bash
./dexmac.sh run WhatsApp        # matched by name
./dexmac.sh run com.whatsapp    # matched by package
```

Name matching is slower — scrcpy has to enumerate installed apps — so prefer the
package name for anything you launch often. Find it with `./dexmac.sh apps`.

### Dock launchers

```bash
./dexmac.sh export com.whatsapp WhatsApp
```

Writes `~/Applications/WhatsApp.command`, which calls the script by absolute path and
so works from anywhere. Drag it to the Dock. Swap in a custom icon via Finder →
Get Info → paste over the icon.

## Configuration

Override any of these in the environment:

| Variable | Default | Notes |
|---|---|---|
| `DEXMAC_RES` | `1920x1080` | virtual display resolution |
| `DEXMAC_DPI` | `240` | lower = smaller UI; try `200` on a 13" screen |
| `DEXMAC_BIG_RES` | `2560x1440` | used by `big` |
| `DEXMAC_CODEC` | `h264` | `h265` is sharper if your encoder handles it |
| `DEXMAC_BITRATE` | `12M` | raise for large windows |

```bash
DEXMAC_DPI=200 DEXMAC_CODEC=h265 ./dexmac.sh run com.whatsapp
```

### scrcpy flags used

- `--flex-display` — resizing the Mac window re-lays-out the Android side rather than
  scaling the image
- `--keep-active` — prevents sleep without touching the device's global screen-timeout
- `--no-vd-destroy-content` — closing the window leaves the app running
- `--audio-source=playback` — captures the app's audio

## Troubleshooting

### Grey panel, no app in it

The display was created and nothing drew on it. Check the terminal output — scrcpy
always says why:

| Log line | Cause | Fix |
|---|---|---|
| `No app found for package "X"` | app name passed as a package name | use the package, or let the script add `?` |
| `Cannot create launch intent for com.sec.android.app.desktoplauncher` | DeX can't start on a virtual display | phone is below One UI 8 — use `run`, not DeX |
| no warning at all | app launched but drew nothing | see FLAG_SECURE below |

### App window is grey but the display works

The app sets `FLAG_SECURE`, and scrcpy's virtual displays aren't secure, so the app
renders nothing. WhatsApp does this when **Settings → Privacy → Screen lock** is on;
banking apps do it unconditionally. Turning the app's own screen-lock off fixes the
former. There's no workaround for the latter without root.

### App opens on the phone instead of the window

Its task is already on the main display. Force-stop and relaunch:

```bash
./adb shell am force-stop com.whatsapp
./dexmac.sh run com.whatsapp
```

Or target the display id scrcpy printed:

```bash
./adb shell am start --display 7 -n com.whatsapp/com.whatsapp.HomeActivity
```

### Distorted or letterboxed layout

Some system and Samsung apps ignore `force_resizable_activities` and letterbox rather
than re-lay-out. Turn it back off if it's causing more harm than good:

```bash
./adb shell settings put global force_resizable_activities 0
```

### Dropped frames with several windows open

Each window is a separate scrcpy process and a separate hardware encoder session.
Most phones start dropping frames around four or five. Lower `DEXMAC_BITRATE`, drop to
`h264`, or close something.

### Encoder errors

scrcpy 4.1 enforces encoder size constraints, and some Samsung encoders report them
incorrectly:

```bash
./scrcpy --new-display=1920x1080/240 --ignore-video-encoder-constraints
```

### Overlay display left on screen

The `overlay on` experiment leaves a translucent panel on the phone. Clear it:

```bash
./dexmac.sh overlay off
```

## Known limitations

- No DeX taskbar, app tray or window manager — macOS manages the windows
- One process per app; no shared desktop between them
- `FLAG_SECURE` apps will never render
- Phone-only apps may letterbox rather than reflow
- Not a DeX replacement on One UI 8+, where scrcpy alone does it better

## Credits

All the real work is [scrcpy](https://github.com/Genymobile/scrcpy) by Romain Vimont
and contributors (Apache-2.0). DeXMac is glue.
