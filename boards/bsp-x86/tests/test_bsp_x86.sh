#!/usr/bin/env bash
# Unit tests for the bsp-x86 board match and first-boot defaults.
# Run: bash boards/bsp-x86/tests/test_bsp_x86.sh
set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
files="$here/../files"
fail=0

check() {
	local name=$1 want=$2 got=$3
	if [[ "$want" == "$got" ]]; then
		echo "ok   $name"
	else
		echo "FAIL $name: want '$want', got '$got'"
		fail=1
	fi
}

# shellcheck source=../files/usr/libexec/bsp-x86/board
. "$files/usr/libexec/bsp-x86/board"

check "vp2430 matches" protectli-vp2430 "$(bsp_x86_role protectli-vp2430)"
check "vp2430e matches" protectli-vp2430 "$(bsp_x86_role protectli-vp2430e)"
check "vault pro spelling matches" protectli-vp2430 "$(bsp_x86_role protectli-vault-pro-vp2430)"
check "other protectli ignored" "" "$(bsp_x86_role protectli-vp2420)"
check "generic x86 ignored" "" "$(bsp_x86_role qemu-standard-pc-i440fx-piix-1996)"
check "board script prints role" protectli-vp2430 "$(sh "$files/usr/libexec/bsp-x86/board" protectli-vp2430)"

# Run a uci-defaults script against a fake board name and a fake uci,
# printing every uci write it makes.
run_defaults() {
	local script=$1 board=$2 device=$3
	(
		tmp=$(mktemp -d)
		trap 'rm -rf "$tmp"' EXIT
		mkdir -p "$tmp/lib" "$tmp/usr/libexec/bsp-x86"
		cat >"$tmp/lib/functions.sh" <<-FN
			board_name() { echo "$board"; }
		FN
		cp "$files/usr/libexec/bsp-x86/board" "$tmp/usr/libexec/bsp-x86/board"
		sed -e "s#/lib/functions.sh#$tmp/lib/functions.sh#" \
			-e "s#/usr/libexec/bsp-x86/board#$tmp/usr/libexec/bsp-x86/board#" \
			"$script" >"$tmp/script"
		uci() {
			[[ "$1" == "-q" ]] && shift
			case "$1" in
			get) echo "$device" ;;
			*) echo "uci $*" ;;
			esac
		}
		# shellcheck disable=SC1091
		. "$tmp/script"
	)
}

gpsd="$files/uci-defaults/40_x86-gpsd-device"
check "gpsd: protectli default device moves to ttyS1" \
	"uci set gpsd.core.device=/dev/ttyS1|uci set gpsd.core.enabled=1|uci commit gpsd" \
	"$(run_defaults "$gpsd" protectli-vp2430 /dev/ttyAMA0 | paste -sd'|')"
check "gpsd: operator device kept" "" \
	"$(run_defaults "$gpsd" protectli-vp2430 /dev/ttyS2 | paste -sd'|')"
check "gpsd: other boards untouched" "" \
	"$(run_defaults "$gpsd" pc-engines-apu2 /dev/ttyAMA0 | paste -sd'|')"

# ntpd config: SHM(1) must be the preferred PPS source.
conf="$files/usr/share/bsp-x86/ntpd.d/gps.conf"
check "ntpd: PPS on SHM(1) preferred" 1 \
	"$(grep -c '^server 127.127.28.1 .*prefer' "$conf")"
check "ntpd: NMEA on SHM(0)" 1 "$(grep -c '^server 127.127.28.0 ' "$conf")"

for f in "$files"/uci-defaults/* "$files"/board.d/* "$files"/hotplug.d/i2c/* \
	"$files"/usr/libexec/bsp-x86/*; do
	if sh -n "$f"; then
		echo "ok   syntax ${f#"$files"/}"
	else
		echo "FAIL syntax ${f#"$files"/}"
		fail=1
	fi
done

exit "$fail"
