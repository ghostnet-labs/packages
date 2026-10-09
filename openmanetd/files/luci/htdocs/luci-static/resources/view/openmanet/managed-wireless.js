/* Stock Network > Wireless view with OpenMANET daemon-managed warnings.
 *
 * The menu entry admin/network/wireless points here (see
 * luci-openmanetd-managed.json). This view installs the warning hook from
 * tools/openmanet/managed.js and then loads the unmodified stock view
 * view/network/wireless.js, which renders itself into #view as usual.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

'use strict';
'require view';
'require tools.openmanet.managed as managed';

return view.extend({
	/* Replaces view.__init__ on purpose: the stock view does the load and
	 * render, this wrapper must not render a second time. */
	__init__: function() {
		return managed.install('wireless').then(function() {
			return L.require('view.network.wireless');
		}).catch(L.error);
	}
});
