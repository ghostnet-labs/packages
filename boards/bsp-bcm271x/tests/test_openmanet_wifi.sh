#!/usr/bin/env bash
# Unit test for board.d/03_openmanet_wifi (D-055 / GHO-89): the 5 GHz
# radio carries the EUD access point on non-DFS channel 36 at low power,
# the 2.4 GHz radio stays enabled with its AP off, 6 GHz is off, and the
# HaLow radio and other boards are left alone.
# Run: bash boards/bsp-bcm271x/tests/test_openmanet_wifi.sh
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
board_script="${script_dir}/../files/board.d/03_openmanet_wifi"

declare -A types=([radio0]=mac80211 [radio1]=mac80211 [radio2]=mac80211 [radio3]=morse)
declare -A bands=([radio0]=2g [radio1]=5g [radio2]=6g [radio3]=s1g)
# radio2 (6 GHz) has no default AP iface, to cover the early return.
declare -A ifaces=([default_radio0]=1 [default_radio1]=1 [default_radio3]=1)
declare -a uci_calls=()
board=""

board_name() { printf '%s\n' "$board"; }
board_config_update() { :; }
board_config_flush() { :; }
config_load() { [[ "$1" == "wireless" ]]; }

config_get() {
	local output_var=$1 section=$2 option=$3
	case "$option" in
	type) printf -v "$output_var" '%s' "${types[$section]}" ;;
	band) printf -v "$output_var" '%s' "${bands[$section]}" ;;
	*) return 1 ;;
	esac
}

config_foreach() {
	local callback=$1
	[[ "$2" == "wifi-device" ]]
	for section in radio0 radio1 radio2 radio3; do
		"$callback" "$section"
	done
}

uci() {
	[[ "$1" == "-q" ]] && shift
	if [[ "$1" == "get" ]]; then
		[[ -n "${ifaces[${2#wireless.}]:-}" ]]
		return
	fi
	uci_calls+=("$*")
}

run_board() {
	board=$1
	uci_calls=()
	# shellcheck disable=SC1090
	source <(sed \
		-e 's|^\. /lib/functions\.sh$|:|' \
		-e 's|^\. /lib/functions/uci-defaults\.sh$|:|' \
		-e 's/^exit 0$/return 0/' \
		"$board_script")
}

fail=0
expect() {
	local name=$1
	shift
	local -a want=("$@")
	if [[ "${uci_calls[*]}" == "${want[*]}" ]]; then
		echo "ok   $name"
		return
	fi
	echo "FAIL $name: got"
	printf '  %s\n' "${uci_calls[@]}"
	fail=1
}

node_calls=(
	'set wireless.radio0.channel=6'
	'set wireless.radio0.country=US'
	'set wireless.radio0.disabled=0'
	'set wireless.default_radio0.ssid=openmanet_2g'
	'set wireless.default_radio0.encryption=psk2'
	'set wireless.default_radio0.key=openmanet'
	'set wireless.default_radio0.disabled=1'
	'set wireless.radio1.channel=36'
	'set wireless.radio1.country=US'
	'set wireless.radio1.txpower=10'
	'set wireless.radio1.disabled=0'
	'set wireless.default_radio1.ssid=openmanet'
	'set wireless.default_radio1.encryption=psk2'
	'set wireless.default_radio1.key=openmanet'
	'delete wireless.default_radio1.disabled'
	'set wireless.radio2.disabled=1'
	'commit wireless'
)

run_board 'ghostnet,v1'
expect "V1: 5 GHz AP, 2.4 GHz on with AP off, 6 GHz off" "${node_calls[@]}"

run_board 'bcm2712,mm8108-usb'
expect "CM5 node: same defaults" "${node_calls[@]}"

run_board 'raspberrypi,5-model-b'
expect "other boards untouched"

exit "$fail"
