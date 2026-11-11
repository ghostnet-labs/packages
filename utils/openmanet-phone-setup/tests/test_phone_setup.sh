#!/usr/bin/env bash
# Unit tests for openmanet-phone-setup with a mocked adb, uci, ubus and
# jsonfilter. No phone or OpenWrt build needed.
# shellcheck disable=SC2034,SC2317,SC2016 # mocks used by the sourced script; literal $ in fakes
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
files="${script_dir}/../files"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

failures=0
fail() {
	printf 'FAIL: %s\n' "$*" >&2
	failures=$((failures + 1))
}

export OPENMANET_PHONE_SETUP_LIB=1
export ONBOARD_DIR="$work/onboard"

# ---- mocks -----------------------------------------------------------------
adb_state=device
adb_devices_out=$'List of devices attached\nR58N123\tdevice'
adb_install_out='Success'
adb_packages='package:com.atakmap.app.civ'
phone_ip='10.41.200.9'
adb() {
	# A file, not an array: pipelines run adb in a subshell.
	printf '%s\n' "$*" >>"$work/adb.log"
	case "$1" in
		devices) printf '%s\n' "$adb_devices_out" ;;
		get-state) printf '%s\n' "$adb_state" ;;
		install) printf 'Performing Streamed Install\r\n%s\r\n' "$adb_install_out" ;;
		shell)
			case "$2 $3" in
				"pm list") printf '%s\r\n' "$adb_packages" ;;
				"getprop ro.product.model") printf 'SM-G556B\r\n' ;;
				"ip -4") [[ -n "$phone_ip" ]] && printf '    inet %s/16 brd 10.41.255.255 scope global wlan0\n' "$phone_ip" ;;
			esac
			;;
	esac
	return 0
}
declare -A uci_vals=(
	[wireless.default_radio1.mode]=ap
	[wireless.default_radio1.network]=ahwlan
	[wireless.default_radio1.ssid]='Manet AP'
	[wireless.default_radio1.encryption]=psk2
	[wireless.default_radio1.key]='s3cret key'
	[wireless.mesh0.mode]=mesh
	[wireless.mesh0.network]=ahwlan
)
uci() {
	[[ "$1" == "-q" ]] && shift
	case "$1" in
		show) printf 'wireless.mesh0=wifi-iface\nwireless.default_radio1=wifi-iface\nwireless.radio1=wifi-device\n' ;;
		get) printf '%s' "${uci_vals[$2]:-}" ;;
	esac
}
node_json='{"ipv4-address":[{"address":"10.41.3.7","mask":16}]}'
ubus() { printf '%s' "$node_json"; }
jsonfilter() { grep -o '"address":"[^"]*"' | head -n1 | cut -d'"' -f4; }
logger() { :; }
sleep() { :; }

# shellcheck disable=SC1091
. "$files/openmanet-phone-setup"

reset() {
	: >"$work/adb.log"
	adb_state=device
	adb_devices_out=$'List of devices attached\nR58N123\tdevice'
	adb_install_out='Success'
	adb_packages='package:com.atakmap.app.civ'
	phone_ip='10.41.200.9'
	mkdir -p "$ONBOARD_DIR"
	: >"$ONBOARD_DIR/atak.apk"
}

# run calls setup_run in this shell (so the adb log survives) and leaves
# its output in $out.
out=''
run() {
	local rc=0
	setup_run "$@" >"$work/out" 2>&1 || rc=$?
	out=$(cat "$work/out")
	return "$rc"
}

log_has() {
	grep -qF -- "$1" "$work/adb.log"
}

# ---- helpers ---------------------------------------------------------------
[[ "$(setup_urlencode 'Bravo 6')" == 'Bravo%206' ]] || fail "urlencode space"
[[ "$(setup_urlencode 'a/b?c=d&e')" == 'a%2Fb%3Fc%3Dd%26e' ]] || fail "urlencode reserved"
[[ "$(setup_package_url 10.41.3.7 8080 '' '' '')" == 'http://10.41.3.7:8080/onboard/atak-setup.zip' ]] ||
	fail "package URL without profile"
[[ "$(setup_package_url 10.41.3.7 8080 'Bravo 6' Cyan '')" == 'http://10.41.3.7:8080/onboard/atak-setup.zip?callsign=Bravo%206&team=Cyan' ]] ||
	fail "package URL with profile: $(setup_package_url 10.41.3.7 8080 'Bravo 6' Cyan '')"
[[ "$(setup_ap)" == $'Manet AP\twpa2\ts3cret key' ]] || fail "AP lookup: $(setup_ap | cat -A)"
uci_vals[wireless.default_radio1.encryption]=sae-mixed
[[ "$(setup_ap | cut -f2)" == wpa3 ]] || fail "SAE should map to wpa3"
uci_vals[wireless.default_radio1.encryption]=none
[[ "$(setup_ap | cut -f2)" == open ]] || fail "no encryption should map to open"
uci_vals[wireless.default_radio1.encryption]=psk2

# ---- full run: happy path ----------------------------------------------------
reset
run --callsign 'Bravo 6' --team Cyan
log_has 'install -r -g' || fail "should install with -g"
log_has 'appops set com.atakmap.app.civ MANAGE_EXTERNAL_STORAGE allow' || fail "should allow all-files storage"
log_has 'deviceidle whitelist +com.atakmap.app.civ' || fail "should exempt ATAK from Doze"
log_has "cmd wifi connect-network 'Manet AP' wpa2 's3cret key'" || fail "should join the node AP"
log_has 'tak://com.atakmap.app/import?url=http%3A%2F%2F10.41.3.7%3A8080%2Fonboard%2Fatak-setup.zip%3Fcallsign%3DBravo%25206%26team%3DCyan' ||
	fail "should open the import link: $(cat "$work/adb.log")"
[[ "$out" == *"tap Import"* ]] || fail "should tell the user to tap Import"

# ---- no APK ------------------------------------------------------------------
reset
rm -f "$ONBOARD_DIR/atak.apk"
if run; then fail "no APK should fail"; fi
[[ "$out" == *"No ATAK file"* ]] || fail "no APK message"
log_has install && fail "no APK should not install"

# ---- unauthorized phone times out with the Allow hint -------------------------
reset
adb_state=unauthorized
adb_devices_out=$'List of devices attached\nR58N123\tunauthorized'
if run --wait 4; then fail "unauthorized should fail"; fi
[[ "$out" == *"tap Allow"* ]] || fail "unauthorized should prompt to tap Allow"

# ---- two phones --------------------------------------------------------------
reset
adb_devices_out=$'List of devices attached\nA\tdevice\nB\tdevice'
if run; then fail "two phones should fail"; fi
[[ "$out" == *"one at a time"* ]] || fail "two phones message"

# ---- install blocked ---------------------------------------------------------
reset
adb_install_out='Failure [INSTALL_FAILED_VERIFICATION_FAILURE]'
if run; then fail "failed install should fail"; fi
[[ "$out" == *"Auto Blocker"* ]] || fail "failed install should mention Auto Blocker"

# ---- phone never joins Wi-Fi -------------------------------------------------
reset
phone_ip=''
run
[[ "$out" == *"did not join Wi-Fi"* ]] || fail "no Wi-Fi should say so"
log_has 'tak://' && fail "no Wi-Fi should not open the import link"

# ---- open AP has no key -----------------------------------------------------
reset
uci_vals[wireless.default_radio1.encryption]=none
setup_run >/dev/null
log_has "cmd wifi connect-network 'Manet AP' open" || fail "open AP join"
uci_vals[wireless.default_radio1.encryption]=psk2

# ---- hotplug filter ----------------------------------------------------------
hook="$files/40-openmanet-phone-setup"
mkdir -p "$work/bin"
printf '#!/bin/sh\nexit 0\n' >"$work/bin/logger"
printf '#!/bin/sh\necho "${UCI_AUTO:-}"\n' >"$work/bin/uci"
printf '#!/bin/sh\necho run >>%q\n' "$work/setup.log" >"$work/bin/fake-setup"
chmod +x "$work/bin/logger" "$work/bin/uci" "$work/bin/fake-setup"
run_hook() {
	env -i PATH="$work/bin:/usr/bin:/bin" OPENMANET_PHONE_SETUP_BIN="$work/bin/fake-setup" \
		UCI_AUTO="${4:-}" ACTION="$1" DEVTYPE="$2" INTERFACE="$3" sh "$hook"
}
: >"$work/setup.log"
run_hook add usb_interface 255/66/1
run_hook remove usb_interface 255/66/1
run_hook add usb_device 255/66/1
run_hook add usb_interface 8/6/80
run_hook add usb_interface 255/66/1 0
for _ in 1 2 3 4 5 6 7 8 9 10; do
	[[ -s "$work/setup.log" ]] && break
	command sleep 0.1
done
[[ "$(wc -l <"$work/setup.log")" == 1 ]] ||
	fail "hook should start setup once (ADB add, auto on), got $(wc -l <"$work/setup.log")"

if ((failures > 0)); then
	printf '%d failure(s)\n' "$failures" >&2
	exit 1
fi
echo "openmanet-phone-setup: all tests passed"
