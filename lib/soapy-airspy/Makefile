include $(TOPDIR)/rules.mk

PKG_NAME:=soapy-airspy
PKG_VERSION:=0.2.1
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/pothosware/SoapyAirspy.git
# Tag soapy-airspy-0.2.1, pinned by commit so a moved tag cannot change the build.
PKG_SOURCE_VERSION:=9a906cac218bf07a7acd31efa1f2954c3a44ea4b
PKG_MIRROR_HASH:=177cfcfba4ede1ce2f33bf2ab369e268396482178908faae1b4e9865d956229a

PKG_MAINTAINER:=info@openmanet.net
PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE.txt

PKG_BUILD_DEPENDS:=soapysdr airspyone_host
PKG_BUILD_PARALLEL:=1
CMAKE_INSTALL:=1

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

define Package/soapy-airspy
  SECTION:=libs
  CATEGORY:=Libraries
  TITLE:=SoapySDR module for Airspy R2 and Mini receivers
  URL:=https://github.com/pothosware/SoapyAirspy
  DEPENDS:=+libsoapysdr +libairspy
endef

define Package/soapy-airspy/description
SoapySDR support module for Airspy R2 and Mini receivers. Lets SoapySDR
clients open the wide tuner by its serial number, which must match exactly
(lowercase hex, as SoapySDRUtil --find="driver=airspy" prints it):
driver=airspy,serial=<serial>
endef

define Package/soapy-airspy/install
	$(INSTALL_DIR) $(1)/usr/lib/SoapySDR/modules0.8
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/SoapySDR/modules0.8/libairspySupport.so \
		$(1)/usr/lib/SoapySDR/modules0.8/
endef

$(eval $(call BuildPackage,soapy-airspy))
