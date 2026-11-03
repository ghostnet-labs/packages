include $(TOPDIR)/rules.mk

PKG_NAME:=airspyone_host
PKG_VERSION:=1.0.12
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/airspy/airspyone_host.git
# master of 2026-07-19, not a tag. The last release tag, v1.0.9, dates from
# 2016: it lacks airspy_list_devices() (2018), which SoapyAirspy needs to
# find a receiver by serial, and later fixes to USB tear-down,
# control-transfer timeouts and thread joins. airspy.h at this commit
# reports 1.0.12, which upstream never tagged.
PKG_SOURCE_VERSION:=fc61ab6be57ed61f0e2bdd9c6dfae74cacef57d0
PKG_MIRROR_HASH:=479b7c10f81b6b507da997778a40c0a6b8d23b2e672203c77a5ee363c178c516

PKG_MAINTAINER:=info@openmanet.net
# Upstream ships no licence file: libairspy is BSD-3-Clause and the tools are
# GPL-2.0-or-later, as stated in each source file's header.
PKG_LICENSE:=BSD-3-Clause GPL-2.0-or-later

PKG_BUILD_PARALLEL:=1
CMAKE_INSTALL:=1

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

define Package/airspyone_host/Default
  URL:=https://github.com/airspy/airspyone_host
endef

define Package/libairspy
  $(call Package/airspyone_host/Default)
  SECTION:=libs
  CATEGORY:=Libraries
  TITLE:=Library for Airspy R2 and Mini receivers
  DEPENDS:=+libusb-1.0 +libpthread
endef

define Package/libairspy/description
libairspy talks to Airspy R2 and Airspy Mini wide-band receivers over
libusb (up to 10 MS/s on the R2). It opens a receiver by its USB serial
number, so it can be claimed without depending on plug order.
endef

define Package/airspy-tools
  $(call Package/airspyone_host/Default)
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Airspy receiver probe and capture tools
  DEPENDS:=+libairspy
endef

define Package/airspy-tools/description
airspy_info lists attached Airspy receivers with their serial numbers and
supported sample rates. airspy_rx records IQ from one receiver, selected
with -s 0x<serial>, to a file or stdout.
endef

# The tools link the library from this build tree (libairspy_SOURCE_DIR is
# set by the top-level project), so nothing has to be staged first. No udev
# rules: OpenWrt has no udev and the services that open the receiver run
# as root.
CMAKE_OPTIONS += -DINSTALL_UDEV_RULES=OFF

define Package/libairspy/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/libairspy.so.* $(1)/usr/lib/
endef

# Only the two tools the bench steps use; the GPIO, clock, tuner register
# and SPI flash tools are for board bring-up and can brick a receiver.
define Package/airspy-tools/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/airspy_info $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/airspy_rx $(1)/usr/bin/
endef

$(eval $(call BuildPackage,libairspy))
$(eval $(call BuildPackage,airspy-tools))
