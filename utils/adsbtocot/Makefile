include $(TOPDIR)/rules.mk

PKG_NAME:=adsbtocot
PKG_VERSION:=9.2.2
PKG_RELEASE:=5

# adsbcot from its git tag, not from PyPI: the PyPI project returns 404 (both
# /simple/adsbcot/ and /pypi/adsbcot/json) as of 2026-11-03, which broke
# every firmware build. This is tag v9.2.2, commit dated 2026-09-04.
PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/snstac/adsbcot.git
PKG_SOURCE_VERSION:=0c143c4355a944728e14b7ee347a8e06c1a7e8c2
PKG_MIRROR_HASH:=43651143f5b5093127ef55d854c70cb379b293e10ca3ea8964df3fd99b63a251

PKG_MAINTAINER:=info@openmanet.net
PKG_LICENSE:=Apache-2.0
PKG_LICENSE_FILES:=LICENSE
HOST_BUILD_DEPENDS:=python3/host
PKGARCH:=all

include $(INCLUDE_DIR)/package.mk

define Package/adsbtocot
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=ADS-B to Cursor-on-Target (ADSBCOT) for OpenWrt (dump1090 local)
  DEPENDS:=+python3 +dump1090 +rtl-sdr
endef

define Package/adsbtocot/description
Installs ADSBCOT, built from its upstream git tag, and provides a procd
service to forward ADS-B tracks from dump1090 to CoT/TAK (multicast or
unicast).
endef

# Persist user edits
define Package/adsbtocot/conffiles
/etc/adsbcot/adsbcot.ini
endef

# adsbcot's runtime dependencies still come from PyPI, pinned to the set that
# resolved for Python 3.11 on 2026-11-03 so an upstream release (or another
# yanked project) cannot change the image under us. adsbcot asks for
# aircot>=1.2.0, pytak>=7.3.12, aiohttp<4 and websockets<11; the rest are
# what those pull in.
ADSBCOT_PYTHON_DEPS:= \
	'aircot==4.0.2' \
	'pytak==7.6.1' \
	'aiohttp==3.14.5' \
	'websockets==10.4' \
	'aiohappyeyeballs==2.7.1' \
	'aiosignal==1.4.0' \
	'attrs==26.1.0' \
	'frozenlist==1.8.0' \
	'idna==3.20' \
	'multidict==7.2.1' \
	'propcache==0.5.4' \
	'typing_extensions==4.16.0' \
	'yarl==1.25.1'

# Vendor ADSBCOT as pure Python:
# - drop 'with_pymodes' to avoid numpy/ELF
# - disable aiohttp/yarl/multidict/frozenlist C-extensions
# - forbid wheels so pip builds pure-Python installs
define Build/Compile
	AIOHTTP_NO_EXTENSIONS=1 \
	YARL_NO_EXTENSIONS=1 \
	MULTIDICT_NO_EXTENSIONS=1 \
	FROZENLIST_NO_EXTENSIONS=1 \
	PIP_NO_BINARY=:all: \
	$(STAGING_DIR_HOSTPKG)/bin/pip3 install '$(PKG_BUILD_DIR)' $(ADSBCOT_PYTHON_DEPS) \
		--prefix=/usr --root='$(PKG_INSTALL_DIR)' --no-cache-dir --no-compile

	# PyTAK imports crypto helpers too early. Patch the vendored install so the
	# default UDP/non-TLS ADSBCOT path works without python3-cryptography.
	perl -0pi -e 's/\nimport pytak\.crypto_classes  # pylint: disable=cyclic-import\n/\n/' \
		'$(PKG_INSTALL_DIR)'/usr/lib/python3*/site-packages/pytak/functions.py
	perl -0pi -e 's/enrollment = pytak\.crypto_classes\.CertificateEnrollment\(\)/from pytak.crypto_classes import CertificateEnrollment\n    enrollment = CertificateEnrollment()/g' \
		'$(PKG_INSTALL_DIR)'/usr/lib/python3*/site-packages/pytak/functions.py
	perl -0pi -e 's/"""\n\nimport asyncio/"""\n\nfrom __future__ import annotations\n\nimport asyncio/' \
		'$(PKG_INSTALL_DIR)'/usr/lib/python3*/site-packages/pytak/crypto_classes.py
	# Fail the build if a pytak update means the patches above stop applying.
	! grep -qE '^import pytak\.crypto_classes|pytak\.crypto_classes\.CertificateEnrollment' \
		'$(PKG_INSTALL_DIR)'/usr/lib/python3*/site-packages/pytak/functions.py
	grep -q '^from __future__ import annotations' \
		'$(PKG_INSTALL_DIR)'/usr/lib/python3*/site-packages/pytak/crypto_classes.py

	# Safety: ensure no native .so crept in
	find '$(PKG_INSTALL_DIR)/usr' -type f \( -name '*.so' -o -name '*.so.*' \) -print -delete || true
endef

define Package/adsbtocot/install
	# Config + init
	$(INSTALL_DIR) $(1)/etc/adsbcot $(1)/etc/init.d
	$(INSTALL_CONF) ./files/adsbcot.ini  $(1)/etc/adsbcot/adsbcot.ini
	$(INSTALL_BIN)  ./files/adsbcot.init $(1)/etc/init.d/adsbcot

	# Python site-packages and console scripts
	$(INSTALL_DIR) $(1)/usr
	cp -a $(PKG_INSTALL_DIR)/usr/* $(1)/usr/

	# Ensure no ELF in final image
	find '$(1)/usr' -type f \( -name '*.so' -o -name '*.so.*' \) -print -delete || true

	# Normalize console-script shebangs to the target Python
	[ -f "$(1)/usr/bin/adsbcot" ] && $(SED) '1s|^#!.*|#!/usr/bin/python3|' "$(1)/usr/bin/adsbcot" && chmod 0755 "$(1)/usr/bin/adsbcot"
	for f in pytak aircot; do \
		if [ -f "$(1)/usr/bin/$$f" ]; then \
			$(SED) '1s|^#!.*|#!/usr/bin/python3|' "$(1)/usr/bin/$$f"; \
			chmod 0755 "$(1)/usr/bin/$$f"; \
		fi; \
	done

	# Trim caches to save space
	find "$(1)/usr/lib/python3"* -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true
	find "$(1)/usr/lib/python3"* -type f -name '*.pyc' -delete 2>/dev/null || true

	# First-boot defaults (gain, ports, etc.)
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/99-adsb-defaults $(1)/etc/uci-defaults/99-adsb-defaults
endef

$(eval $(call BuildPackage,adsbtocot))
