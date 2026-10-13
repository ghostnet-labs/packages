include $(TOPDIR)/rules.mk

PKG_NAME:=soapy-rtlsdr
PKG_VERSION:=0.3.3
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/pothosware/SoapyRTLSDR.git
# Tag soapy-rtl-sdr-0.3.3, pinned by commit so a moved tag cannot change the build.
PKG_SOURCE_VERSION:=80c93fbe189def3ab68d47a6ad3f813f96d3cb99
PKG_MIRROR_HASH:=55a41cb63cb454b829ed468fbb12c32d34e7ddd31f44c4f29e5463fc4a7e1b2b

PKG_MAINTAINER:=info@openmanet.net
PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE.txt

PKG_BUILD_DEPENDS:=soapysdr
PKG_BUILD_PARALLEL:=1
CMAKE_INSTALL:=1

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

define Package/soapy-rtlsdr
  SECTION:=libs
  CATEGORY:=Libraries
  TITLE:=SoapySDR module for RTL2832U receivers
  URL:=https://github.com/pothosware/SoapyRTLSDR
  DEPENDS:=+libsoapysdr +librtlsdr
endef

define Package/soapy-rtlsdr/description
SoapySDR support module for RTL-SDR (RTL2832U) receivers. Lets SoapySDR
clients such as dump978-fa open a receiver by USB serial number:
driver=rtlsdr,serial=978
endef

define Package/soapy-rtlsdr/install
	$(INSTALL_DIR) $(1)/usr/lib/SoapySDR/modules0.8
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/SoapySDR/modules0.8/librtlsdrSupport.so \
		$(1)/usr/lib/SoapySDR/modules0.8/
endef

$(eval $(call BuildPackage,soapy-rtlsdr))
