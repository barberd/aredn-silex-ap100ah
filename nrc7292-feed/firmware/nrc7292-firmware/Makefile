include $(TOPDIR)/rules.mk

PKG_NAME:=nrc7292-firmware
PKG_VERSION:=1.5.1
PKG_RELEASE:=1

PKG_LICENSE:=Proprietary

include $(INCLUDE_DIR)/package.mk

define Package/nrc7292-firmware
  SECTION:=firmware
  CATEGORY:=Firmware
  TITLE:=Newracom NRC7292 firmware and board data
  DEPENDS:=+kmod-nrc7292
endef

define Package/nrc7292-firmware/description
  Firmware binary and board calibration data for the NRC7292 802.11ah chip.
  Includes nrc7292_cspi.bin (chip firmware) and nrc7292_bd.dat (TX power tables).
endef

define Build/Compile
	true
endef

define Package/nrc7292-firmware/install
	$(INSTALL_DIR) $(1)/lib/firmware
	$(INSTALL_DATA) ./files/nrc7292_cspi.bin $(1)/lib/firmware/
	$(INSTALL_DATA) ./files/nrc7292_bd.dat $(1)/lib/firmware/
endef

$(eval $(call BuildPackage,nrc7292-firmware))
