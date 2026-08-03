#!/bin/bash
#
# Captures the App Store screenshots, for every platform and every locale the
# listing is written in, straight into fastlane/screenshots/ where `deliver`
# picks them up.
#
#   Scripts/screenshots.sh                        # iPhone, iPad and Mac, ja + en-US
#   Scripts/screenshots.sh --platform ios         # one platform
#   Scripts/screenshots.sh --locales ja           # one locale
#   Scripts/screenshots.sh --devices iphone       # one iOS device
#
# How it works: the app is pointed at Scripts/screenshot-server.rb — a stub that
# answers the proxy's paths from the decoding tests' fixtures — so the same inns
# at the same prices come out of every run. A UI test walks it through the
# screens and saves a PNG of each; iPhone and iPad shots come off the simulator
# at exactly the pixel sizes App Store Connect asks for, and the Mac's window is
# photographed off the desktop and composed onto a backdrop at 2880x1800.
#
# Anything the run cannot do it says out loud rather than quietly shipping a
# gap: see the summary it prints at the end.
set -euo pipefail

cd "$(dirname "$0")/.."
readonly ROOT="$PWD"
readonly WORK_DIR_NAME="org.ngsdev.iphone.Yado.screenshots"
# The macOS UI test runner is sandboxed: its home is this container, and that is
# the one directory both it and this script can write to.
readonly MAC_RUNNER_BUNDLE_ID="org.ngsdev.iphone.YadoScreenshots.xctrunner"
readonly APP_BUNDLE_ID="org.ngsdev.iphone.Yado"
# Simulators the run creates for itself, so it never shoots on one you are
# signed into iCloud on — an Apple Account prompt mid-run puts your email
# address in the screenshot.
readonly DEVICE_PREFIX="YadoSearch Shot"
readonly DERIVED_DATA="$ROOT/.build/screenshots"
readonly OUTPUT_ROOT="$ROOT/fastlane/screenshots"
readonly API_PORT="${YADO_SCREENSHOT_PORT:-8099}"

# The two the listing is written in. App Store Connect falls back to the
# primary language wherever a localization has no screenshots of its own.
# <App Store locale>:<language>:<region>.
readonly DEFAULT_LOCALES=(
  "ja:ja:JP"
  "en-US:en:US"
)

# iPhone 6.9" and iPad 13" are the only iOS sizes Apple still asks for; the
# smaller classes are scaled from them automatically.
readonly IPHONE_DEVICE="iPhone 17 Pro Max"
readonly IPAD_DEVICE="iPad Pro 13-inch (M5) (16GB)"

readonly MAC_WIDTH=2880
readonly MAC_HEIGHT=1800
readonly MAC_BACKDROP="$ROOT/fastlane/screenshots/mac/backdrop.png"

platforms=(ios mac)
devices=(iphone ipad)
locales=("${DEFAULT_LOCALES[@]}")
failures=()
compositor=""
server_pid=""

usage() {
  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }

# --- arguments ---------------------------------------------------------------

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform | --platforms)
      IFS=',' read -r -a platforms <<<"$2"
      shift 2
      ;;
    --device | --devices)
      IFS=',' read -r -a devices <<<"$2"
      shift 2
      ;;
    --locales)
      requested=()
      IFS=',' read -r -a wanted <<<"$2"
      for want in "${wanted[@]}"; do
        if [[ "$want" == "all" ]]; then
          requested=("${DEFAULT_LOCALES[@]}")
          break
        fi
        match=""
        for known in "${DEFAULT_LOCALES[@]}"; do
          [[ "${known%%:*}" == "$want" ]] && match="$known"
        done
        if [[ -z "$match" ]]; then
          echo "error: unknown locale '$want'. Known: ${DEFAULT_LOCALES[*]%%:*}" >&2
          exit 2
        fi
        requested+=("$match")
      done
      locales=("${requested[@]}")
      shift 2
      ;;
    -h | --help) usage 0 ;;
    *)
      echo "error: unknown option '$1'" >&2
      usage 2
      ;;
  esac
done

mkdir -p "$DERIVED_DATA"

# --- the stub proxy ----------------------------------------------------------

start_server() {
  if lsof -nP -iTCP:"$API_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    log "something is already listening on $API_PORT — using it"
    return
  fi
  ruby "$ROOT/Scripts/screenshot-server.rb" --port "$API_PORT" \
    >"$DERIVED_DATA/api.log" 2>&1 &
  server_pid=$!
  for _ in $(seq 1 30); do
    if lsof -nP -iTCP:"$API_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
      log "stub proxy on 127.0.0.1:$API_PORT"
      return
    fi
    sleep 0.2
  done
  echo "error: the stub proxy never came up — see $DERIVED_DATA/api.log" >&2
  exit 1
}

cleanup() {
  [[ -n "$server_pid" ]] && kill "$server_pid" 2>/dev/null || true
}
trap cleanup EXIT

# --- helpers -----------------------------------------------------------------

# Prints the udid of the simulator to shoot on, creating it on the first run.
# They are kept between runs; delete them from Xcode whenever you like.
device_udid() {
  local model="$1"
  xcrun simctl list --json |
    MODEL="$model" PREFIX="$DEVICE_PREFIX" python3 -c '
import json, os, sys
model, prefix = os.environ["MODEL"], os.environ["PREFIX"]
catalogue = json.load(sys.stdin)
name = f"{prefix} {model}"

for entries in catalogue["devices"].values():
    for device in entries:
        if device["name"] == name and device.get("isAvailable", True):
            print(device["udid"])
            sys.exit(0)

kinds = [k for k in catalogue["devicetypes"] if k["name"] == model]
if not kinds:
    sys.exit(f"no simulator model named {model!r} is installed")
kind = kinds[0]["identifier"]

runtimes = [
    r for r in catalogue["runtimes"]
    if r["isAvailable"] and any(d["identifier"] == kind for d in r.get("supportedDeviceTypes", []))
]
if not runtimes:
    sys.exit(f"no installed runtime supports {model!r}")
runtimes.sort(key=lambda r: [int(p) for p in r["version"].split(".")])
print("create", kind, runtimes[-1]["identifier"], sep="\t")
' >"$DERIVED_DATA/device.txt" 2>"$DERIVED_DATA/device.err" || {
    cat "$DERIVED_DATA/device.err" >&2
    return 1
  }

  local answer
  answer="$(cat "$DERIVED_DATA/device.txt")"
  if [[ "$answer" == create* ]]; then
    local kind runtime
    kind="$(echo "$answer" | cut -f2)"
    runtime="$(echo "$answer" | cut -f3)"
    log "creating a clean simulator: $DEVICE_PREFIX $model" >&2
    xcrun simctl create "$DEVICE_PREFIX $model" "$kind" "$runtime"
  else
    echo "$answer"
  fi
}

# The directory the test and this script meet in: config in, PNGs out.
work_dir() {
  local udid="${1:-}"
  if [[ -n "$udid" ]]; then
    echo "$HOME/Library/Developer/CoreSimulator/Devices/$udid/data/Library/Caches/$WORK_DIR_NAME"
  else
    echo "$HOME/Library/Containers/$MAC_RUNNER_BUNDLE_ID/Data/Library/Caches/$WORK_DIR_NAME"
  fi
}

# Writes the config the test reads: which language, which proxy, and whether
# the host takes the picture.
write_config() {
  local dir="$1" language="$2" region="$3" external="$4" orientation="${5:-portrait}"
  mkdir -p "$dir"
  rm -f "$dir"/*.png "$dir"/capture-request-* "$dir"/capture-done-*
  cat >"$dir/config.json" <<JSON
{
  "language": "$language",
  "region": "$region",
  "apiHost": "127.0.0.1:$API_PORT",
  "orientation": "$orientation",
  "externalCapture": $external
}
JSON
}

# Collects what the test produced into the tree `deliver` uploads from.
#
# Files are named <order>_<screen>_<device>.png: deliver decides *which* store
# size a file belongs to by its pixel dimensions, and only uses the name to
# order the shots within that size — so the iPhone and iPad files share a
# directory.
collect() {
  local dir="$1" platform="$2" locale="$3" suffix="$4"
  local destination="$OUTPUT_ROOT/$platform/$locale"
  mkdir -p "$destination"
  local collected=0
  for file in "$dir"/*.png; do
    [[ -e "$file" ]] || continue
    local base
    base="$(basename "$file" .png)"
    cp "$file" "$destination/${base}_${suffix}.png"
    collected=$((collected + 1))
  done
  if [[ $collected -eq 0 ]]; then
    failures+=("$platform/$locale/$suffix: the run produced no screenshots")
    return 1
  fi
  log "$platform/$locale: $collected shots ($suffix)"
}

build_compositor() {
  local source="$ROOT/Scripts/compose_mac_screenshot.swift"
  local binary="$DERIVED_DATA/compose_mac_screenshot"
  if [[ ! -x "$binary" || "$source" -nt "$binary" ]]; then
    swiftc -O -o "$binary" "$source" >/dev/null
  fi
  echo "$binary"
}

# Boots a simulator and freezes its status bar at the time Apple's own
# marketing shots use.
prepare_simulator() {
  local udid="$1"
  xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 || true
  xcrun simctl status_bar "$udid" override \
    --time "9:41" \
    --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 \
    --batteryState charged --batteryLevel 100 >/dev/null 2>&1 ||
    warn "could not override the status bar on $udid"
}

# Runs one capture pass: one destination, one locale.
#
# Simulators run unsigned builds happily, which keeps the run independent of
# whatever certificates this machine has. macOS does not: an unsigned test
# runner is killed on launch, so there the build signs itself as usual.
run_test() {
  local destination="$1" log_file="$2"
  local signing=(CODE_SIGNING_ALLOWED=NO)
  local provisioning=()
  if [[ "$destination" == "platform=macOS" ]]; then
    # Signed as usual, and allowed to fetch a development profile: the app has
    # the iCloud and push entitlements, so an ad-hoc signature will not do.
    signing=()
    provisioning=(-allowProvisioningUpdates)
  fi
  xcodebuild test \
    -workspace "$ROOT/YadoSearch.xcworkspace" \
    -scheme "YadoSearchScreenshots" \
    -destination "$destination" \
    -derivedDataPath "$DERIVED_DATA" \
    ${signing[@]+"${signing[@]}"} \
    ${provisioning[@]+"${provisioning[@]}"} \
    >"$log_file" 2>&1
}

# The Mac shots the test cannot take itself: it drops a `capture-request-<name>`
# file, holds the app still, and waits for `capture-done-<name>`. A UI test
# *can* photograph the window, but it flattens it — the rounded corners come
# back filled with black and the system's drop shadow is gone. `screencapture`
# hands back what macOS actually draws.
watch_for_captures() {
  local dir="$1" test_pid="$2"
  while kill -0 "$test_pid" 2>/dev/null; do
    for request in "$dir"/capture-request-*; do
      [[ -e "$request" ]] || continue
      local name="${request##*capture-request-}"
      capture_mac_window "$dir/$name.png" || warn "screencapture could not photograph $name"
      rm -f "$request"
      touch "$dir/capture-done-$name"
    done
    sleep 0.2
  done
}

capture_mac_window() {
  local output="$1" window
  window="$("$compositor" --window-id "$APP_BUNDLE_ID")" || return 1
  # -l: that window alone. No -o: keep the drop shadow. -x: no shutter sound.
  screencapture -x -l "$window" "$output"
}

# --- platforms ---------------------------------------------------------------

shoot_simulator() {
  local device="$1" suffix="$2" orientation="${3:-portrait}"
  local udid
  if ! udid="$(device_udid "$device")"; then
    failures+=("ios/$suffix: no simulator named '$device' is installed")
    warn "skipping $suffix: no simulator named '$device'"
    return
  fi
  prepare_simulator "$udid"
  local dir
  dir="$(work_dir "$udid")"

  for entry in "${locales[@]}"; do
    IFS=':' read -r locale language region <<<"$entry"
    log "ios · $device · $locale"
    # Favourites, history and recent searches survive between runs, and a
    # screenshot showing what the *last* run did is not the screenshot anyone
    # asked for. The app is removed so every pass starts empty.
    xcrun simctl uninstall "$udid" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
    write_config "$dir" "$language" "$region" "false" "$orientation"

    local log_file="$DERIVED_DATA/ios-$suffix-$locale.log"
    if ! run_test "id=$udid" "$log_file"; then
      failures+=("ios/$locale/$suffix: the capture run failed — see $log_file")
      warn "ios/$locale/$suffix failed; see $log_file"
      continue
    fi
    # A landscape run comes off the simulator in the device's *physical*
    # frame: the content is rotated inside a portrait image, because
    # XCUIScreen photographs the screen and the screen never turned. Turning
    # the file back is the whole fix — the pixels are already right.
    if [[ "$orientation" == "landscape" ]]; then
      for file in "$dir"/*.png; do
        [[ -e "$file" ]] || continue
        sips -r 270 "$file" >/dev/null
      done
    fi
    collect "$dir" "ios" "$locale" "$suffix" || true
  done
}

shoot_mac() {
  local dir
  dir="$(work_dir)"
  compositor="$(build_compositor)"
  for entry in "${locales[@]}"; do
    IFS=':' read -r locale language region <<<"$entry"
    log "mac · $locale"
    # Same reason as the simulator's uninstall: favourites and history must not
    # arrive from the last run.
    rm -rf "$HOME/Library/Containers/$APP_BUNDLE_ID"
    write_config "$dir" "$language" "$region" "true"

    local log_file="$DERIVED_DATA/mac-$locale.log"
    run_test "platform=macOS" "$log_file" &
    local test_pid=$!
    watch_for_captures "$dir" "$test_pid"
    if ! wait "$test_pid"; then
      failures+=("mac/$locale: the capture run failed — see $log_file")
      warn "mac/$locale failed; see $log_file"
      continue
    fi
    for file in "$dir"/*.png; do
      [[ -e "$file" ]] || continue
      "$compositor" "$file" "$file" "$MAC_WIDTH" "$MAC_HEIGHT" "$MAC_BACKDROP"
    done
    collect "$dir" "mac" "$locale" "desktop" || true
  done
}

# --- run ---------------------------------------------------------------------

start_server

for platform in "${platforms[@]}"; do
  case "$platform" in
    ios)
      for device in "${devices[@]}"; do
        case "$device" in
          iphone) shoot_simulator "$IPHONE_DEVICE" iphone portrait ;;
          # The iPad is shot wide: that is the shape the sidebar layout is for.
          ipad) shoot_simulator "$IPAD_DEVICE" ipad landscape ;;
          *)
            echo "error: unknown device '$device'" >&2
            exit 2
            ;;
        esac
      done
      ;;
    mac) shoot_mac ;;
    *)
      echo "error: unknown platform '$platform'" >&2
      exit 2
      ;;
  esac
done

echo
if [[ ${#failures[@]} -gt 0 ]]; then
  warn "${#failures[@]} part(s) of the run did not produce screenshots:"
  for failure in "${failures[@]}"; do
    printf '  - %s\n' "$failure" >&2
  done
  exit 1
fi

log "Done. Review $OUTPUT_ROOT, then upload with:"
echo "      bundle exec fastlane ios deliver_screenshots"
echo "      bundle exec fastlane mac deliver_screenshots"
