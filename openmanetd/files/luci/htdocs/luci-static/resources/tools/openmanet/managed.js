/* Daemon-managed setting warnings for the stock LuCI network views.
 *
 * openmanetd rewrites some UCI values on its own schedule, so an edit made in
 * LuCI can be silently undone. This module marks those values with a
 * non-blocking warning in the stock Network > Interfaces and Network >
 * Wireless views, without forking them:
 *
 *  - network interface 'ahwlan' (device br-ahwlan) and its DHCP pool: the
 *    address reservation worker (internal/mgmt/address_reservation.go)
 *    rewrites proto/ipaddr/netmask/ip6class/ip6ifaceid/ip6assign/device and
 *    the dhcp start/limit/leasetime/force, then reboots, when the address is
 *    unconfigured (openmanetd.config.dhcpconfigured != 1) or conflicts with
 *    a mesh peer. The section is the daemon's meshNetInterface (default
 *    br-ahwlan) without its br- prefix.
 *  - every wifi-iface with network 'batmesh1' and mode 'mesh': at each start
 *    reconcileBatMesh1Options (internal/mgmt/device.go) re-adds any missing
 *    mcast_rate, mesh_nolearn, mesh_retry_timeout, mesh_confirm_timeout or
 *    mesh_holding_timeout. Existing values are kept.
 *
 * The view wrappers in view/openmanet/ call install() and then load the stock
 * view. install() wraps form.Map.prototype.renderContents so that every
 * render of the page map, and of the edit modal of a managed section, gets
 * the warning as its first element after the map title and description.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

'use strict';
'require baseclass';
'require form';
'require uci';

var MESH_INTERFACE = 'ahwlan';
var MESH_DEVICE = 'br-' + MESH_INTERFACE;
var BATMESH1_NETWORK = 'batmesh1';

var INTERFACE_OPTIONS = [ 'proto', 'ipaddr', 'netmask', 'ip6class', 'ip6ifaceid', 'ip6assign', 'device' ];
var DHCP_OPTIONS = [ 'start', 'limit', 'leasetime', 'force' ];
var BATMESH1_OPTIONS = [ 'mcast_rate', 'mesh_nolearn', 'mesh_retry_timeout', 'mesh_confirm_timeout', 'mesh_holding_timeout' ];

var NOTICE_ATTR = 'data-openmanet-managed';

var page = null;
var origRenderContents = null;

function contains(value, wanted) {
	return L.toArray(value).indexOf(wanted) != -1;
}

/* Network interface sections the address reservation worker writes. */
function managedInterfaces() {
	return uci.sections('network', 'interface').filter(function(s) {
		return s['.name'] == MESH_INTERFACE;
	}).map(function(s) {
		return s['.name'];
	});
}

/* DHCP pools of a managed interface (the daemon names its pool after the
 * interface; LuCI matches pools by their interface option). */
function managedDHCPPools(ifname) {
	return uci.sections('dhcp', 'dhcp').filter(function(s) {
		return s['.name'] == ifname || s.interface == ifname;
	}).map(function(s) {
		return s['.name'];
	});
}

/* wifi-iface sections reconcileBatMesh1Options keeps tuned. */
function managedBatMesh1Ifaces() {
	return uci.sections('wireless', 'wifi-iface').filter(function(s) {
		return contains(s.network, BATMESH1_NETWORK) && s.mode == 'mesh';
	}).map(function(s) {
		return s['.name'];
	});
}

/* null when the openmanetd config could not be read. */
function reservationDone() {
	var v = uci.get('openmanetd', 'config', 'dhcpconfigured');

	return (v == null) ? null : (v == '1');
}

function notice(kind, paragraphs) {
	var nodes = [ E('strong', {}, [ _('Managed by OpenMANET.') ]), ' ', paragraphs[0] ];

	for (var i = 1; i < paragraphs.length; i++)
		nodes.push(E('br'), paragraphs[i]);

	var attrs = { 'class': 'alert-message warning' };

	attrs[NOTICE_ATTR] = kind;

	return E('div', attrs, nodes);
}

function interfaceParagraphs(ifname) {
	var pools = managedDHCPPools(ifname),
	    done = reservationDone(),
	    p = [];

	p.push(_('The openmanetd daemon owns the mesh bridge interface "%s" (device %s) and its DHCP pool. When the address is unconfigured or conflicts with another mesh node it rewrites the interface options %s and the DHCP pool options %s, then reboots.')
		.format(ifname, MESH_DEVICE, INTERFACE_OPTIONS.join(', '), DHCP_OPTIONS.join(', ')));

	if (pools.length)
		p.push(_('Daemon-managed DHCP pool: %s.').format(pools.join(', ')));

	p.push(_('Changes made here may be reverted at the next daemon start or address check.'));

	if (done === false)
		p.push(_('Address reservation has not completed on this node yet (dhcpconfigured is 0), so the next check overwrites these settings, removes the "lan" interface and its DHCP pool on non-gateway nodes, and reboots.'));

	return p;
}

function wirelessParagraphs(ifaces) {
	return [
		_('The openmanetd daemon owns the tuning of the batmesh1 mesh link (%s). It re-adds any of the options %s that are missing; values already set are kept.')
			.format(ifaces.join(', '), BATMESH1_OPTIONS.join(', ')),
		_('Removing these options here may be reverted at the next daemon start.')
	];
}

function isPageMap(map, sectiontype) {
	return map.parent == null && L.toArray(map.children).some(function(s) {
		return s instanceof form.GridSection && s.sectiontype == sectiontype;
	});
}

function isModalFor(map, sections) {
	return map.parent != null && map.section != null && sections.indexOf(map.section) != -1;
}

/* Returns the warning for this map render, or null. */
function noticeFor(map) {
	var ifaces;

	if (page == 'interfaces' && map.config == 'network') {
		ifaces = managedInterfaces();

		if (!ifaces.length)
			return null;

		if (isPageMap(map, 'interface'))
			return notice('interfaces', interfaceParagraphs(ifaces[0]));

		if (isModalFor(map, ifaces))
			return notice('interface', interfaceParagraphs(map.section));
	}
	else if (page == 'wireless' && map.config == 'wireless') {
		ifaces = managedBatMesh1Ifaces();

		if (!ifaces.length)
			return null;

		if (isPageMap(map, 'wifi-device'))
			return notice('wireless', wirelessParagraphs(ifaces));

		if (isModalFor(map, ifaces))
			return notice('wifi-iface', wirelessParagraphs([ map.section ]));
	}

	return null;
}

function decorate(map, mapEl) {
	var node = noticeFor(map),
	    anchor = null;

	if (!node || !mapEl || mapEl.querySelector(':scope > [' + NOTICE_ATTR + ']'))
		return;

	for (var child = mapEl.firstElementChild; child; child = child.nextElementSibling) {
		if (child.tagName == 'H2' || child.classList.contains('cbi-map-descr'))
			anchor = child;
		else
			break;
	}

	mapEl.insertBefore(node, anchor ? anchor.nextSibling : mapEl.firstChild);
}

return baseclass.extend({
	MESH_INTERFACE: MESH_INTERFACE,
	BATMESH1_NETWORK: BATMESH1_NETWORK,

	managedInterfaces: managedInterfaces,
	managedDHCPPools: managedDHCPPools,
	managedBatMesh1Ifaces: managedBatMesh1Ifaces,
	noticeFor: noticeFor,

	/* Hooks form.Map rendering for page ('interfaces' or 'wireless').
	 * Never rejects: a missing or unreadable openmanetd config only drops
	 * the reservation-state sentence. */
	install: function(name) {
		page = name;

		if (origRenderContents == null) {
			origRenderContents = form.Map.prototype.renderContents;

			form.Map.prototype.renderContents = function() {
				var map = this;

				return origRenderContents.apply(this, arguments).then(function(mapEl) {
					try {
						decorate(map, mapEl);
					}
					catch (e) {
						console.warn('openmanet: daemon-managed notice failed', e);
					}

					return mapEl;
				});
			};
		}

		return uci.load('openmanetd').catch(function() {});
	}
});
