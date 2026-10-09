'use strict';
/*
 * "Back to OpenMANET" return control (GHO-73, unified UI design D-037).
 *
 * LuCI is reachable two ways:
 *   1. Through the openmanetd frontend proxy (frontend.luciProxy.enable), on
 *      the OpenMANET origin: https://<node>:8081 or http://<node>:8080. LuCI
 *      then shares the origin with the OpenMANET UI, so the way back is "/".
 *   2. Directly from uhttpd on the default ports (http :80, or https :443
 *      when luci-ssl is installed). This is the recovery route. The OpenMANET
 *      UI lives on another port there, so the way back is the canonical
 *      HTTPS frontend: https://<host>:8081/.
 *
 * The server cannot tell the two apart (the proxy talks to uhttpd on
 * loopback :80 either way), so the rule is decided in the browser from the
 * page's own port:
 *   location.port is "" / "80" / "443"  ->  https://<host>:8081/
 *   any other port                      ->  "/"
 *
 * location.hostname keeps the brackets of an IPv6 literal ("[fe80::1]"), so
 * the absolute URL stays valid for IPv6 hosts too.
 */
(function () {
	var DIRECT_PORTS = { '': true, '80': true, '443': true };

	function openmanetReturnURL(loc) {
		var port = (loc && loc.port) || '';

		if (DIRECT_PORTS[port])
			return 'https://' + loc.hostname + ':8081/';

		return '/';
	}

	function apply() {
		try {
			var target = openmanetReturnURL(window.location),
			    links = document.querySelectorAll('a[data-om-return]');

			for (var i = 0; i < links.length; i++)
				links[i].setAttribute('href', target);
		}
		catch (e) {
			/* Keep the server-rendered href ("/") if anything goes wrong. */
		}
	}

	if (typeof module === 'object' && module.exports)
		module.exports = { openmanetReturnURL: openmanetReturnURL, apply: apply };

	if (typeof document === 'undefined')
		return;

	if (document.readyState === 'loading')
		document.addEventListener('DOMContentLoaded', apply);
	else
		apply();
})();
