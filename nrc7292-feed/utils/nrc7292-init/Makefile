include $(TOPDIR)/rules.mk

PKG_NAME:=nrc7292-init
PKG_VERSION:=1.0
PKG_RELEASE:=1

PKG_LICENSE:=GPL-2.0

include $(INCLUDE_DIR)/package.mk

define Package/nrc7292-init
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=NRC7292 initialization script
  DEPENDS:=+kmod-nrc7292 +nrc7292-firmware
endef

define Package/nrc7292-init/description
  Init script for the NRC7292 802.11ah WiFi chip.
  Handles GPIO reset and module loading with correct parameters.
endef

define Build/Compile
	true
endef

define Package/nrc7292-init/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/nrc7292 $(1)/etc/init.d/nrc7292
endef

$(eval $(call BuildPackage,nrc7292-init))
