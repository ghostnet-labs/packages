include $(TOPDIR)/rules.mk

PKG_NAME:=soapysdr
PKG_VERSION:=0.8.1
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/pothosware/SoapySDR.git
# Tag soapy-sdr-0.8.1, pinned by commit so a moved tag cannot change the build.
PKG_SOURCE_VERSION:=1cf5a539a21414ff509ff7d0eedfc5fa8edb90c6
PKG_MIRROR_HASH:=f6d6639a9bb4685d8094beb9569224f06dfeaa08b9313af27b7e0f09e3078238

PKG_MAINTAINER:=info@openmanet.net
PKG_LICENSE:=BSL-1.0
PKG_LICENSE_FILES:=LICENSE_1_0.txt

PKG_BUILD_PARALLEL:=1
CMAKE_INSTALL:=1

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

define Package/soapysdr/Default
  URL:=https://github.com/pothosware/SoapySDR
endef

define Package/libsoapysdr
  $(call Package/soapysdr/Default)
  SECTION:=libs
  CATEGORY:=Libraries
  TITLE:=SoapySDR vendor-neutral SDR device library
  DEPENDS:=+libstdcpp +libpthread
endef

define Package/libsoapysdr/description
SoapySDR is a vendor-neutral and platform-independent library for
software-defined radio hardware. Device support comes from separately
packaged modules (for example soapy-rtlsdr), loaded at run time from
/usr/lib/SoapySDR/modules0.8.
endef

define Package/soapysdr-util
  $(call Package/soapysdr/Default)
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=SoapySDRUtil device discovery and probe tool
  DEPENDS:=+libsoapysdr
endef

define Package/soapysdr-util/description
SoapySDRUtil lists, probes and rate-tests SoapySDR devices
(SoapySDRUtil --find, --probe="driver=rtlsdr,serial=978").
endef

CMAKE_OPTIONS += \
	-DENABLE_APPS=ON \
	-DENABLE_DOCS=OFF \
	-DENABLE_PYTHON=OFF \
	-DENABLE_PYTHON3=OFF \
	-DENABLE_TESTS=OFF

# Stage headers, the library and the CMake package config (used by
# soapy-rtlsdr), but not SoapySDR.pc. dump1090 (FlightAware 9.0, packages
# feed) autodetects SoapySDR through pkg-config and would link it without
# declaring the dependency, failing its package build whenever soapysdr
# happens to be staged first. dump978-fa links -lSoapySDR directly.
define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include $(1)/usr/lib $(1)/usr/share/cmake
	$(CP) $(PKG_INSTALL_DIR)/usr/include/SoapySDR $(1)/usr/include/
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/libSoapySDR.so* $(1)/usr/lib/
	$(CP) $(PKG_INSTALL_DIR)/usr/share/cmake/SoapySDR $(1)/usr/share/cmake/
endef

define Package/libsoapysdr/install
	$(INSTALL_DIR) $(1)/usr/lib/SoapySDR/modules0.8
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/libSoapySDR.so* $(1)/usr/lib/
endef

define Package/soapysdr-util/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/SoapySDRUtil $(1)/usr/bin/
endef

$(eval $(call BuildPackage,libsoapysdr))
$(eval $(call BuildPackage,soapysdr-util))
