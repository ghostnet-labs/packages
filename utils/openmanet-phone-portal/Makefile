include $(TOPDIR)/rules.mk

PKG_NAME:=openmanet-phone-portal
PKG_VERSION:=1.0
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_MAINTAINER:=OpenMANET

include $(INCLUDE_DIR)/package.mk

define Package/openmanet-phone-portal
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Open the phone setup page when a phone joins the node
  DEPENDS:=+uhttpd +dnsmasq +jsonfilter
  PKGARCH:=all
endef

define Package/openmanet-phone-portal/description
  When the node has no internet, a phone that joins its access point
  gets a "Sign in to network" prompt that opens openmanetd's /join page
  (install and set up ATAK from the node). It answers the phone's
  connectivity check names with the node's own address and redirects the
  check to /join. With internet the phone's check passes as normal.
endef

define Package/openmanet-phone-portal/conffiles
/etc/config/openmanet_portal
endef

define Build/Compile
endef

define Package/openmanet-phone-portal/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/openmanet-phone-portal $(1)/usr/sbin/openmanet-phone-portal

	$(INSTALL_DIR) $(1)/www/cgi-bin
	$(INSTALL_BIN) ./files/openmanet-portal.cgi $(1)/www/cgi-bin/openmanet-portal

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/openmanet-phone-portal.init $(1)/etc/init.d/openmanet-phone-portal

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/openmanet_portal.config $(1)/etc/config/openmanet_portal

	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/60_openmanet_phone_portal $(1)/etc/uci-defaults/60_openmanet_phone_portal
endef

define Package/openmanet-phone-portal/postinst
#!/bin/sh
# On a live install (not an image build) uhttpd must pick up error_page.
[ -n "$${IPKG_INSTROOT}" ] || /etc/init.d/uhttpd reload
exit 0
endef

$(eval $(call BuildPackage,openmanet-phone-portal))
