include $(TOPDIR)/rules.mk

PKG_NAME:=nrc7292-cli-app
PKG_VERSION:=1.5.1
PKG_RELEASE:=1

PKG_LICENSE:=ISC

include $(INCLUDE_DIR)/package.mk

define Package/nrc7292-cli-app
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=NRC7292 radio control utility (cli_app)
  DEPENDS:=+kmod-nrc7292 +libpthread
endef

define Package/nrc7292-cli-app/description
  Command-line utility for controlling the NRC7292 802.11ah radio.
  Uses the driver's netlink interface for runtime configuration
  of guard interval, CCA threshold, TX power, and other parameters.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR) \
		CC="$(TARGET_CC)" \
		AR="$(TARGET_AR)" \
		CFLAGS="$(TARGET_CFLAGS) -pthread" \
		LFLAGS="-L./ -lcli_app -lm -pthread"
endef

define Package/nrc7292-cli-app/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/cli_app $(1)/usr/bin/cli_app
endef

$(eval $(call BuildPackage,nrc7292-cli-app))
