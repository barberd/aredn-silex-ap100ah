DEVICE_VARS += UBOOT

include common.mk

define Device/Default
  PROFILES := Default
  FILESYSTEMS := squashfs ext4
  KERNEL_INSTALL := 1
  KERNEL_SUFFIX := -uImage
  KERNEL_NAME := zImage
  KERNEL := kernel-bin | uImage none
  KERNEL_LOADADDR := 0x80008000
  DTS_DIR := $(DTS_DIR)/nxp/imx
  IMAGES :=
endef

define Device/silex_ap-100ah
  DEVICE_VENDOR := Silex
  DEVICE_MODEL := AP-100AH
  DEVICE_DTS := imx6ull-ap100ah
  KERNEL_NAME := zImage
  KERNEL := kernel-bin
  KERNEL_SUFFIX := -zImage
  KERNEL_LOADADDR := 0x80008000
  FILESYSTEMS := squashfs
  IMAGES := squashfs-sysupgrade.bin
  IMAGE/squashfs-sysupgrade.bin := sysupgrade-tar | append-metadata
  DEVICE_PACKAGES := kmod-nrc7292 nrc7292-firmware nrc7292-init nrc7292-cli-app \
	iw hostapd wpa-supplicant wireless-regdb wifi-scripts
  SUPPORTED_DEVICES := silex,ap-100ah
endef
TARGET_DEVICES += silex_ap-100ah
