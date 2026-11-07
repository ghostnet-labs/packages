include $(TOPDIR)/rules.mk

PKG_NAME:=openmanet-phone-setup
PKG_VERSION:=1.0
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_MAINTAINER:=OpenMANET

include $(INCLUDE_DIR)/package.mk

define Package/openmanet-phone-setup
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Set up ATAK on a phone plugged into the node
  DEPENDS:=+adb +jsonfilter
  PKGARCH:=all
endef

define Package/openmanet-phone-setup/description
  Plug an Android phone with USB debugging on into the node and it gets
  ATAK from the node's copy with every permission granted, battery saving
  off for ATAK, the node's Wi-Fi joined, and the node's settings package
  opened in ATAK. No internet needed.
endef

define Package/openmanet-phone-setup/conffiles
/etc/config/openmanet_phone_setup
endef

define Build/Compile
endef

define Package/openmanet-phone-setup/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/openmanet-phone-setup $(1)/usr/sbin/openmanet-phone-setup

	$(INSTALL_DIR) $(1)/etc/hotplug.d/usb
	$(INSTALL_DATA) ./files/40-openmanet-phone-setup $(1)/etc/hotplug.d/usb/40-openmanet-phone-setup

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/openmanet_phone_setup.config $(1)/etc/config/openmanet_phone_setup

	$(INSTALL_DIR) $(1)/lib/upgrade/keep.d
	$(INSTALL_DATA) ./files/openmanet-phone-setup.keep $(1)/lib/upgrade/keep.d/openmanet-phone-setup
endef

$(eval $(call BuildPackage,openmanet-phone-setup))
