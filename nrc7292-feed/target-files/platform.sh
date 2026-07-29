. /lib/imx.sh

RAMFS_COPY_BIN='blkid jffs2reset'

platform_check_image() {
	return 0
}

platform_do_upgrade() {
	local board=$(board_name)

	case "$board" in
	silex,ap-100ah)
		local tar_file="$1"
		local board_dir="$(tar tf "$tar_file" | grep -m 1 '^sysupgrade-.*/$')"
		board_dir="${board_dir%/}"

		if tar tf "$tar_file" | grep -q "$board_dir/fdt"; then
			tar xf "$tar_file" -O "$board_dir/fdt" | mtd write - "fdt"
		fi
		tar xf "$tar_file" -O "$board_dir/kernel" | mtd write - "kernel"
		tar xf "$tar_file" -O "$board_dir/root" | mtd -r write - "rootfs"
		;;
	technexion,imx7d-pico-pi)
		imx_sdcard_do_upgrade "$1"
		;;
	esac
}

platform_copy_config() {
	local board=$(board_name)

	case "$board" in
	technexion,imx7d-pico-pi)
		imx_sdcard_copy_config
		;;
	esac
}

platform_pre_upgrade() {
	local board=$(board_name)

	case "$board" in
	technexion,imx7d-pico-pi)
		imx_sdcard_pre_upgrade
		;;
	esac
}
