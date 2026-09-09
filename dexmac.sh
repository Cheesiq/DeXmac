#!/usr/bin/env bash
#
# dexmac.sh — DeX-style Android app windows on macOS via scrcpy
#
# For Galaxy devices that CAN'T run DeX on a virtual display (One UI 7 and
# earlier / Android <= 15). Instead of one DeX desktop, each app gets its own
# resizable virtual display, which scrcpy renders as a normal Mac window.
#
# Requires: scrcpy >= 4.0 (for --flex-display), adb, USB debugging on.
# Both are picked up from this script's own directory if present, else PATH.
#
set -euo pipefail

usage() {
  cat <<'EOF'
dexmac.sh — DeX-style Android app windows on macOS via scrcpy

  ./dexmac.sh setup                 one-time: enable freeform + resizable apps
  ./dexmac.sh apps                  list installed packages
  ./dexmac.sh run <pkg|?name>       open an app in its own window
  ./dexmac.sh big <pkg|?name>       same, but 2560x1440 for wide windows
  ./dexmac.sh blank                 empty virtual display (drag apps onto it)
  ./dexmac.sh export <pkg> <Name>   make a double-clickable .command launcher
  ./dexmac.sh overlay on|off        try the legacy overlay-display DeX trick
  ./dexmac.sh doctor                show device / display / version state

Env overrides: DEXMAC_RES, DEXMAC_DPI, DEXMAC_BIG_RES, DEXMAC_CODEC, DEXMAC_BITRATE
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"

# --- locate adb: prefer one sitting next to this script ----------------------
if [[ -x "$SCRIPT_DIR/adb" ]]; then
  ADB="$SCRIPT_DIR/adb"
elif command -v adb >/dev/null 2>&1; then
  ADB="$(command -v adb)"
else
  echo "error: no adb found next to this script or on PATH." >&2
  exit 1
fi
export ADB   # scrcpy spawns its own adb; keep it on the same binary

# --- locate scrcpy: prefer the portable binary next to this script -----------
if [[ -x "$SCRIPT_DIR/scrcpy" ]]; then
  SCRCPY="$SCRIPT_DIR/scrcpy"
elif command -v scrcpy >/dev/null 2>&1; then
  SCRCPY="$(command -v scrcpy)"
else
  echo "error: no scrcpy found next to this script or on PATH." >&2
  echo "       either cd into the folder holding ./scrcpy, or: brew install scrcpy" >&2
  exit 1
fi

# A portable build needs to be told where its server jar lives.
if [[ -z "${SCRCPY_SERVER_PATH:-}" && -f "$SCRIPT_DIR/scrcpy-server" ]]; then
  export SCRCPY_SERVER_PATH="$SCRIPT_DIR/scrcpy-server"
fi

RES="${DEXMAC_RES:-1920x1080}"
DPI="${DEXMAC_DPI:-240}"
BIG_RES="${DEXMAC_BIG_RES:-2560x1440}"
CODEC="${DEXMAC_CODEC:-h264}"
BITRATE="${DEXMAC_BITRATE:-12M}"

common_flags=(
  --flex-display           # window resize re-lays-out the Android side
  --keep-active            # no sleep, without touching global timeout
  --no-vd-destroy-content  # closing the window doesn't kill the app
  --video-codec="$CODEC"
  --video-bit-rate="$BITRATE"
  --audio-source=playback
)

launch() {
  local res="$1" pkg="$2"
  "$SCRCPY" --new-display="${res}/${DPI}" \
            --start-app="$pkg" \
            --window-title="$pkg" \
            "${common_flags[@]}"
}

case "${1:-}" in
  setup)
    "$ADB" shell settings put global force_resizable_activities 1
    "$ADB" shell settings put global enable_freeform_support 1
    "$ADB" shell settings put global development_settings_enabled 1
    echo "Freeform + forced-resizable enabled. Reboot the phone if apps still refuse to resize."
    ;;

  apps)
    "$SCRCPY" --list-apps
    ;;

  run)
    [[ $# -ge 2 ]] || { echo "usage: $0 run <pkg|?name>" >&2; exit 1; }
    launch "$RES" "$2"
    ;;

  big)
    [[ $# -ge 2 ]] || { echo "usage: $0 big <pkg|?name>" >&2; exit 1; }
    launch "$BIG_RES" "$2"
    ;;

  blank)
    "$SCRCPY" --new-display="${RES}/${DPI}" "${common_flags[@]}"
    ;;

  export)
    [[ $# -ge 3 ]] || { echo "usage: $0 export <pkg> <Name>" >&2; exit 1; }
    out="$HOME/Applications/${3}.command"
    mkdir -p "$HOME/Applications"
    cat > "$out" <<EOF
#!/usr/bin/env bash
exec "$SELF" run "$2"
EOF
    chmod +x "$out"
    echo "Wrote $out — double-click it, or drag it to the Dock."
    ;;

  overlay)
    case "${2:-}" in
      on)  "$ADB" shell settings put global overlay_display_devices "${RES}/320"
           echo "Overlay display set. Now run:  $SCRCPY --list-displays"
           echo "If a new id appears, mirror it: $SCRCPY --display-id=N" ;;
      off) "$ADB" shell settings put global overlay_display_devices null
           echo "Overlay display cleared." ;;
      *)   echo "usage: $0 overlay on|off" >&2; exit 1 ;;
    esac
    ;;

  doctor)
    echo "adb:       $ADB"
    "$ADB" version | head -1
    echo "scrcpy:    $SCRCPY"
    "$SCRCPY" --version | head -1
    echo "server:    ${SCRCPY_SERVER_PATH:-<default lookup>}"
    echo "device:    $("$ADB" shell getprop ro.product.model | tr -d '\r')"
    echo "android:   $("$ADB" shell getprop ro.build.version.release | tr -d '\r')"
    echo "one ui:    $("$ADB" shell getprop ro.build.version.oneui | tr -d '\r')"
    echo "freeform:  $("$ADB" shell settings get global enable_freeform_support | tr -d '\r')"
    echo "resizable: $("$ADB" shell settings get global force_resizable_activities | tr -d '\r')"
    echo "overlay:   $("$ADB" shell settings get global overlay_display_devices | tr -d '\r')"
    echo "--- displays ---"
    "$SCRCPY" --list-displays
    ;;

  *)
    usage
    exit 1
    ;;
esac
