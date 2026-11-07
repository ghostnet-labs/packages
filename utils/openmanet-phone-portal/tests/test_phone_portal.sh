#!/usr/bin/env bash
# Unit tests for openmanet-phone-portal (daemon and CGI), run with mocked
# ping, ubus, jsonfilter, killall, logger and uci. No OpenWrt build needed.
# shellcheck disable=SC2034,SC2317 # vars and mocks are used by sourced scripts
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

export PORTAL_HOSTS_FILE="$work/hosts/openmanet-portal"
export OPENMANET_PORTAL_LIB=1

# ---- mocks -----------------------------------------------------------------
ping_ok=0     # 1: every check address answers
hup_count=0
declare -A iface_json=(
	[ahwlan]='{"ipv4-address":[{"address":"10.41.3.7","mask":16}]}'
	[lan]='{"ipv4-address":[{"address":"192.168.1.1","mask":24}]}'
)
ping() { [[ "$ping_ok" == 1 ]]; }
ubus() { printf '%s' "${iface_json[${2#network.interface.}]:-}"; }
jsonfilter() { grep -o '"address":"[^"]*"' | cut -d'"' -f4; }
killall() { [[ "$*" == *"-HUP dnsmasq"* ]] && hup_count=$((hup_count + 1)); return 0; }
logger() { :; }
uci_join_port=''
uci() { printf '%s' "$uci_join_port"; }

# shellcheck disable=SC1091
. "$files/openmanet-phone-portal"
# shellcheck disable=SC1091
. "$files/openmanet-portal.cgi"

PORTAL_NETWORKS="ahwlan lan"
PORTAL_CHECK_IPS="1.1.1.1"

reset_state() {
	rm -rf "$work/hosts"
	PORTAL_LAST=''
	PORTAL_STATE=''
	hup_count=0
}

# ---- daemon: first check applies at once -------------------------------------
reset_state
ping_ok=0
portal_step
[[ -f "$PORTAL_HOSTS_FILE" ]] || fail "offline at start should write the hosts file"
[[ "$PORTAL_STATE" == offline ]] || fail "state should be offline, got $PORTAL_STATE"
[[ "$hup_count" == 1 ]] || fail "dnsmasq should be told once, got $hup_count"
grep -qx '10.41.3.7 connectivitycheck.gstatic.com' "$PORTAL_HOSTS_FILE" ||
	fail "Android check name should point at the AP address"
grep -qx '192.168.1.1 captive.apple.com' "$PORTAL_HOSTS_FILE" ||
	fail "iPhone check name should point at the lan address too"

# ---- daemon: unchanged file does not reload dnsmasq --------------------------
portal_step
[[ "$hup_count" == 1 ]] || fail "rewriting the same file should not reload dnsmasq, got $hup_count"

# ---- daemon: a single good ping does not flip --------------------------------
ping_ok=1
portal_step
[[ -f "$PORTAL_HOSTS_FILE" ]] || fail "one good ping should not remove the hosts file"
portal_step
[[ ! -f "$PORTAL_HOSTS_FILE" ]] || fail "two good pings should remove the hosts file"
[[ "$PORTAL_STATE" == online ]] || fail "state should be online, got $PORTAL_STATE"
[[ "$hup_count" == 2 ]] || fail "removal should reload dnsmasq, got $hup_count"

# ---- daemon: flapping never toggles ------------------------------------------
for ok in 0 1 0 1; do
	ping_ok=$ok
	portal_step
done
[[ ! -f "$PORTAL_HOSTS_FILE" ]] || fail "alternating results should leave the state alone"

# ---- daemon: online at start writes nothing ----------------------------------
reset_state
ping_ok=1
portal_step
[[ ! -f "$PORTAL_HOSTS_FILE" ]] || fail "online at start should not write the hosts file"
[[ "$hup_count" == 0 ]] || fail "online at start should not reload dnsmasq"

# ---- daemon: no address means no file ----------------------------------------
reset_state
ping_ok=0
iface_json=()
portal_step
[[ ! -f "$PORTAL_HOSTS_FILE" ]] || fail "no node address should not write a hosts file"
iface_json=(
	[ahwlan]='{"ipv4-address":[{"address":"10.41.9.9","mask":16}]}'
)

# ---- daemon: address change is picked up while offline -----------------------
portal_step
grep -qx '10.41.9.9 connectivitycheck.gstatic.com' "$PORTAL_HOSTS_FILE" ||
	fail "a new node address should be written while offline"

# ---- CGI: which hosts redirect -----------------------------------------------
for h in connectivitycheck.gstatic.com CAPTIVE.APPLE.COM www.google.com:80 \
	detectportal.firefox.com. some.unknown-vendor.example; do
	portal_is_check_host "$h" || fail "should redirect host '$h'"
done
for h in '' 10.41.3.7 10.41.3.7:80 '[fd00::1]' '[fd00::1]:80' openmanet \
	localhost node7.lan node7.local tiles.manet router.home.arpa; do
	if portal_is_check_host "$h"; then fail "should not redirect host '$h'"; fi
done

# ---- CGI: redirect response ----------------------------------------------------
mkdir -p "$work/hosts" && : >"$PORTAL_HOSTS_FILE"
out=$(HTTP_HOST=connectivitycheck.gstatic.com SERVER_ADDR=10.41.3.7 portal_respond)
[[ "$out" == "Status: 302 Found"* ]] || fail "check host should get a 302, got: ${out%%$'\r'*}"
grep -q $'^Location: http://10.41.3.7:8080/join\r$' <<<"$out" ||
	fail "redirect should go to /join on the address the phone used"

uci_join_port=8443
out=$(HTTP_HOST=captive.apple.com SERVER_ADDR=fd41::7 portal_respond)
grep -q $'^Location: http://\[fd41::7\]:8443/join\r$' <<<"$out" ||
	fail "IPv6 server address should be bracketed and join_port honored"
uci_join_port='bad'
out=$(HTTP_HOST=captive.apple.com SERVER_ADDR=10.41.3.7 portal_respond)
grep -q $'^Location: http://10.41.3.7:8080/join\r$' <<<"$out" ||
	fail "a bad join_port should fall back to 8080"

# ---- CGI: plain 404s ---------------------------------------------------------
out=$(HTTP_HOST=10.41.3.7 SERVER_ADDR=10.41.3.7 portal_respond)
[[ "$out" == "Status: 404 Not Found"* ]] || fail "an IP host should keep its 404"

rm -f "$PORTAL_HOSTS_FILE"
out=$(HTTP_HOST=connectivitycheck.gstatic.com SERVER_ADDR=10.41.3.7 portal_respond)
[[ "$out" == "Status: 404 Not Found"* ]] || fail "with the portal off a check host should keep its 404"

# ---- uci-defaults: sets error_page only when unset ---------------------------
uci_log=()
current_error_page=''
uci() {
	if [[ "$1" == "-q" && "$2" == "get" ]]; then
		printf '%s' "$current_error_page"
		return 0
	fi
	uci_log+=("$*")
}
# shellcheck disable=SC1090
source <(sed -e 's/^exit 0$/return 0/' -e 's/&& exit 0$/\&\& return 0/' \
	"$files/60_openmanet_phone_portal")
[[ "${uci_log[*]}" == "set uhttpd.main.error_page=/cgi-bin/openmanet-portal commit uhttpd" ]] ||
	fail "uci-defaults should set error_page, got: ${uci_log[*]}"
uci_log=()
current_error_page='/custom-404'
# shellcheck disable=SC1090
source <(sed -e 's/^exit 0$/return 0/' -e 's/&& exit 0$/\&\& return 0/' \
	"$files/60_openmanet_phone_portal")
[[ "${#uci_log[@]}" == 0 ]] || fail "uci-defaults should keep an existing error_page"

if ((failures > 0)); then
	printf '%d failure(s)\n' "$failures" >&2
	exit 1
fi
echo "openmanet-phone-portal: all tests passed"
