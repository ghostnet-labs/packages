#!/bin/sh
# shellcheck shell=dash # busybox ash: local is supported
#
# uhttpd 404 handler (uhttpd.main.error_page). While the node has no
# internet, openmanet-phone-portal points phones' connectivity check names
# at this node, so a check such as
#   GET http://connectivitycheck.gstatic.com/generate_204
# arrives here as a 404. Answer it with a redirect to openmanetd's /join
# page on the address the phone used, which makes the phone show "Sign in
# to network". Every other request (an IP address, a node name, or any
# request while the portal is off) keeps its plain 404.

PORTAL_HOSTS_FILE=${PORTAL_HOSTS_FILE:-/tmp/hosts/openmanet-portal}

# portal_is_check_host succeeds for a host name that is not this node: it
# has a dot, is not an IP literal and is not a local name.
portal_is_check_host() {
	local host=$1
	case "$host" in
		'' | \[*) return 1 ;; # empty or IPv6 literal
	esac
	host=${host%%:*}
	host=$(printf '%s' "$host" | tr '[:upper:]' '[:lower:]')
	host=${host%.}
	case "$host" in
		*[!0-9.]*) ;;   # has a letter: a name
		*) return 1 ;; # IPv4 literal
	esac
	case "$host" in
		*.*) ;;
		*) return 1 ;; # single label, e.g. the node's own name
	esac
	case "$host" in
		localhost | *.lan | *.local | *.manet | *.home.arpa | *.internal) return 1 ;;
	esac
	return 0
}

portal_join_port() {
	local port
	port=$(uci -q get openmanet_portal.main.join_port 2>/dev/null)
	case "$port" in
		'' | *[!0-9]*) port=8080 ;;
	esac
	printf '%s' "$port"
}

portal_join_url() {
	local addr=$1 port=$2
	case "$addr" in
		*:*) addr="[$addr]" ;;
	esac
	printf 'http://%s:%s/join' "$addr" "$port"
}

portal_respond() {
	if [ -f "$PORTAL_HOSTS_FILE" ] && [ -n "$SERVER_ADDR" ] &&
		portal_is_check_host "$HTTP_HOST"; then
		local url
		url=$(portal_join_url "$SERVER_ADDR" "$(portal_join_port)")
		printf 'Status: 302 Found\r\n'
		printf 'Location: %s\r\n' "$url"
		printf 'Cache-Control: no-store\r\n'
		printf 'Content-Type: text/html\r\n\r\n'
		printf '<!doctype html><title>Set up your phone</title>'
		printf '<a href="%s">Set up your phone</a>\n' "$url"
		return 0
	fi

	printf 'Status: 404 Not Found\r\n'
	printf 'Content-Type: text/plain\r\n\r\n'
	printf 'Not found\n'
}

[ -n "$OPENMANET_PORTAL_LIB" ] || portal_respond
