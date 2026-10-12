include $(TOPDIR)/rules.mk

PKG_NAME:=bsp-x86
PKG_RELEASE=1
PKG_VERSION:=1.0

PKG_LICENSE:=GPLv2
PKG_LICENSE_FILES:=

PKG_MAINTAINER:=OpenMANET
PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk

define Package/bsp-x86
	SECTION:=utils
	CATEGORY:=OpenMANET
	SUBMENU:=Boards
	TITLE:=OpenMANET x86 board support package
	DEPENDS:=+bsp-common +gpsd +ntpd +kmod-pps-ldisc +kmod-usb-hid-mcp2221 \
		+kmod-hwmon-ina2xx
endef

define Package/bsp-x86/description
Board support for OpenMANET nodes built on x86_64 boxes. Today that is the
Protectli Vault Pro VP2430 bench node: GNSS NMEA and PPS on the RS-232 COM
port (/dev/ttyS1, PPS on DCD through the pps-ldisc line discipline) feeding
ntpd, and an INA260 battery monitor on an MCP2221A USB-I2C bridge. Every
script checks the board name, so the package is inert on other x86 hardware.
endef

define Build/Compile

endef

define Package/bsp-x86/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults/
	$(INSTALL_DATA) ./files/uci-defaults/* $(1)/etc/uci-defaults/

	$(INSTALL_DIR) $(1)/etc/board.d/
	$(INSTALL_BIN) ./files/board.d/* $(1)/etc/board.d/

	$(INSTALL_DIR) $(1)/etc/hotplug.d/i2c/
	$(INSTALL_DATA) ./files/hotplug.d/i2c/* $(1)/etc/hotplug.d/i2c/

	$(INSTALL_DIR) $(1)/usr/libexec/bsp-x86/
	$(INSTALL_BIN) ./files/usr/libexec/bsp-x86/* $(1)/usr/libexec/bsp-x86/

	# Installed to /etc/ntpd.d/ on first boot by uci-defaults, only on
	# boards whose GNSS PPS reaches gpsd (see 43_x86-ntpd-gps).
	$(INSTALL_DIR) $(1)/usr/share/bsp-x86/ntpd.d/
	$(INSTALL_DATA) ./files/usr/share/bsp-x86/ntpd.d/* $(1)/usr/share/bsp-x86/ntpd.d/
endef

$(eval $(call BuildPackage,bsp-x86))
