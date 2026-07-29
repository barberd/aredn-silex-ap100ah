include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=nrc7292
PKG_VERSION:=1.5.1
PKG_RELEASE:=1

PKG_LICENSE:=GPL-2.0

include $(INCLUDE_DIR)/package.mk

define KernelPackage/nrc7292
  SUBMENU:=Wireless Drivers
  TITLE:=Newracom NRC7292 802.11ah (HaLow) driver
  DEPENDS:=+kmod-cfg80211 +kmod-mac80211
  FILES:=$(PKG_BUILD_DIR)/nrc.ko
  AUTOLOAD:=
endef

define KernelPackage/nrc7292/description
  Kernel module for the Newracom NRC7292 802.11ah (Wi-Fi HaLow) chip.
  Uses SPI (CSPI) host interface. Requires nrc7292-firmware package.
endef

NOSTDINC_FLAGS = \
	-I$(PKG_BUILD_DIR) \
	-I$(STAGING_DIR)/usr/include/mac80211-backport/uapi \
	-I$(STAGING_DIR)/usr/include/mac80211-backport \
	-I$(STAGING_DIR)/usr/include/mac80211/uapi \
	-I$(STAGING_DIR)/usr/include/mac80211 \
	-include backport/autoconf.h \
	-include backport/backport.h

include $(INCLUDE_DIR)/kernel-defaults.mk

define Build/Compile
	$(MAKE) -C "$(LINUX_DIR)" \
		$(KERNEL_MAKE_FLAGS) \
		M="$(PKG_BUILD_DIR)" \
		NOSTDINC_FLAGS="$(NOSTDINC_FLAGS)" \
		modules
endef

$(eval $(call KernelPackage,nrc7292))
