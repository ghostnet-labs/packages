include $(TOPDIR)/rules.mk

PKG_NAME:=dump978-fa
PKG_VERSION:=9.0
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/flightaware/dump978.git
# Tag v9.0, pinned by commit so a moved tag cannot change the build.
PKG_SOURCE_VERSION:=40b24ad9263a9a50d92ae8e235dba61c6705d83b
PKG_MIRROR_HASH:=6e69771f64fbebecad67a0fda428404e2ffc564f537ff300d3d408073d37d006

PKG_MAINTAINER:=info@openmanet.net
PKG_LICENSE:=BSD-2-Clause LGPL-2.1-or-later MIT
PKG_LICENSE_FILES:=LICENSE libs/fec/lesser.txt

# boost: headers (asio, regex and optional are header-only in 1.86) plus the
# compiled program_options and filesystem libraries.
PKG_BUILD_DEPENDS:=boost soapysdr
PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk

define Package/dump978-fa
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=FlightAware 978 MHz UAT (ADS-B) decoder
  URL:=https://github.com/flightaware/dump978
  DEPENDS:=+libstdcpp +libpthread +boost +boost-program_options +boost-filesystem \
	+libsoapysdr +soapy-rtlsdr
endef

define Package/dump978-fa/description
dump978-fa decodes US 978 MHz UAT (ADS-B) from an RTL-SDR receiver through
SoapySDR. skyaware978 turns its raw stream into aircraft.json. The procd
service claims the receiver by RTL-SDR USB serial (default "978") so the UAT
receiver is never taken by the 1090 decoder or a scanner.
endef

define Package/dump978-fa/conffiles
/etc/config/dump978-fa
endef

# The upstream Makefile appends -Werror -O2 -g and derives VERSION from git.
# Command-line variables replace those with the target flags and the pinned
# version (the Makefile still adds -DVERSION to CPPFLAGS). boost_regex and
# boost_system are header-only in Boost 1.86, so they are dropped from LIBS:
# linking boost_regex would pull ICU into the image.
define Build/Compile
	$(MAKE) $(PKG_JOBS) -C $(PKG_BUILD_DIR) \
		$(TARGET_CONFIGURE_OPTS) \
		VERSION="$(PKG_VERSION)" \
		CFLAGS="$(TARGET_CFLAGS) $(TARGET_CPPFLAGS) -Wall -Ilibs" \
		CXXFLAGS="$(TARGET_CXXFLAGS) $(TARGET_CPPFLAGS) -std=c++11 -Wall -Wno-psabi -Ilibs" \
		LDFLAGS="$(TARGET_LDFLAGS) -Wl,--as-needed" \
		LIBS="-lboost_program_options -lboost_filesystem -lpthread" \
		LIBS_SDR="-lSoapySDR" \
		dump978-fa skyaware978
endef

define Package/dump978-fa/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/dump978-fa $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/skyaware978 $(1)/usr/bin/
	$(INSTALL_DIR) $(1)/etc/init.d $(1)/etc/config
	$(INSTALL_BIN) ./files/dump978-fa.init $(1)/etc/init.d/dump978-fa
	$(INSTALL_CONF) ./files/dump978-fa.config $(1)/etc/config/dump978-fa
endef

$(eval $(call BuildPackage,dump978-fa))
