# AREDN for Silex AP-100AH

[AREDN](https://www.arednmesh.org/) mesh networking firmware for the [Silex AP-100AH / BR-100AH](https://www.silextechnology.com/connectivity-solutions/wifi-access-point/ap-100ah) 802.11ah (Wi-Fi HaLow) access point.

Based on AREDN 4.26.7.0 with NRC7292 HaLow radio support. See [CHANGES-FROM-STOCK-AREDN.md](CHANGES-FROM-STOCK-AREDN.md) for a complete list of modifications.

## Hardware

| Component | Detail |
|-----------|--------|
| SoC | NXP i.MX6ULL (ARM Cortex-A7, single core) |
| RAM | 128 MB DDR3 |
| Flash | 32 MB Winbond QSPI NOR |
| Ethernet | 10/100 Mbps (FEC, single port) |
| WiFi | Newracom NRC7292 802.11ah HaLow (SPI) |
| Console | UART @ 115200 8N1 (3.3V TTL) |

## Status

- ✅ AREDN web UI
- ✅ Ethernet with AREDN VLAN tagging (untagged=LAN, VLAN 1=WAN, VLAN 2=DtD)
- ✅ NRC7292 HaLow radio — IBSS mesh mode
- ✅ Babel mesh routing
- ✅ WireGuard tunnels
- ✅ Sysupgrade support
- ✅ `cli_app` (Newracom radio control utility)
- ✅ LED triggers (power, wifi activity, LAN activity)

## Install

### From Stock Silex Firmware

1. Download `APBR-100-aredn.bin` from the [Releases page](../../releases)
2. Open the stock web UI (default: `http://192.168.0.254`)
3. Navigate to **Maintenance** → **Firmware Update**
4. Upload `APBR-100-aredn.bin`
5. Wait for reboot (~60 seconds)

> ⚠️ Once flashed, the stock web UI is gone. Recovery requires serial console + TFTP (see below).

### From OpenWrt (AP-100AH running [openwrt-silex-ap100ah](https://github.com/barberd/openwrt-silex-ap100ah))

```sh
cd /tmp
wget https://github.com/barberd/aredn-silex-ap100ah/releases/download/v4.26.7.0/aredn-n3lp-4.26.7.0-93ad9ea9-imx-cortexa7-silex_ap-100ah-squashfs-squashfs-sysupgrade.bin -O aredn.bin
sysupgrade -n aredn.bin
```

### Upgrading from Running AREDN

From the device console (telnet to the LAN IP):

```sh
cd /tmp
wget https://github.com/barberd/aredn-silex-ap100ah/releases/download/v4.26.7.0/aredn-n3lp-4.26.7.0-93ad9ea9-imx-cortexa7-silex_ap-100ah-squashfs-squashfs-sysupgrade.bin -O aredn.bin
sysupgrade aredn.bin
```

Without `-n` to keep your existing configuration (node name, channel, network settings).

### First Boot

After flashing, AREDN will boot and configure itself. The first boot includes an automatic reboot (AREDN regenerates configs). After the second boot settles:

- Connect ethernet to the device
- You will receive a DHCP address on a 10.x.x.x/29 subnet
- Open the web UI at the gateway IP shown in your DHCP lease

Follow the [AREDN First Boot Setup Guide](https://docs.arednmesh.org/en/latest/arednGettingStarted/firstboot_setup.html) to configure your node name, password, and radio settings.

## Network Layout (Single Ethernet Port)

| Traffic | VLAN | Description |
|---------|------|-------------|
| LAN | untagged | Local devices (laptops, cameras) |
| WAN | 1 (tagged) | Internet/home network gateway |
| DtD | 2 (tagged) | Device-to-device mesh routing |

A VLAN-aware switch is needed to access WAN and DtD from separate ports.

## NRC7292 Channel Mapping

The NRC7292 operates on 902-928 MHz but presents as a standard 2.4/5 GHz radio to the OS. The AREDN UI shows real HaLow frequencies and S1G channel numbers.

**AREDN default**: Channel 5 (904.5 MHz), 1 MHz bandwidth, IBSS mode, SSID `AREDN-5-1-v3`

The full channel mapping is in `/etc/nrc7292-channels.json` on the device.

## Recovery via Serial Console + TFTP

### Serial Header

Inside the case, four pin holes next to the reset button (3.3V TTL, 115200 8N1):
```
[board edge]
  ○  GND
  ○  RX  (connect to adapter TX)
  ○  TX  (connect to adapter RX)
  ○  3.3V (DO NOT CONNECT)
[reset button]
```

### TFTP Setup

Download `aredn-n3lp-4.26.7.0-tftp.zip` from the [Releases page](../../releases) and extract to your TFTP server root.

Configure your PC's ethernet interface:

```sh
sudo ip addr add 192.168.0.1/24 dev eth0
sudo dnsmasq --no-daemon --enable-tftp --tftp-root=/srv/tftp
```

The U-Boot default TFTP server is `192.168.0.1`. If your setup differs, change it in U-Boot: `setenv serverip <your-ip>; saveenv`

### Flashing from U-Boot

Interrupt U-Boot boot (hold spacebar while powering on), then:

```
run update_fdt
run update_kernel
run update_rootfs
reset
```

### Restoring Stock Firmware

Download the stock firmware from [Silex](https://www.silextechnology.com/connectivity-solutions/wifi-access-point/ap-100ah), extract the DTB/kernel/rootfs, place on TFTP server, and use the same U-Boot commands above.

## Building

### Prerequisites

- Linux build host
- ~15 GB disk space
- Build dependencies: `git quilt build-essential libncurses5-dev libssl-dev python3 unzip gawk gettext wget flex`

### Build Steps

```bash
# Clone AREDN at 4.26.7.0
git clone --branch 4.26.7.0 https://github.com/aredn/aredn.git aredn-build
cd aredn-build

# Remove morse feed (incompatible with NRC7292)
sed -i '/morse/d' feeds.conf
echo "src-link nrc7292 $(pwd)/nrc7292-feed" >> feeds.conf

# Comment out morsemicro patches
sed -i 's/^790-morsemicro-support.patch/#&/' patches/series
sed -i 's/^791-morsemicro-remove-patches.patch/#&/' patches/series
echo "810-define-aredn-imx-networks.patch" >> patches/series

# Copy configs and patches from this repo
cp <this-repo>/configs/imx-cortexa7-nrc7292.config configs/
cp <this-repo>/patches/810-define-aredn-imx-networks.patch patches/

# Modify Makefile: replace morse feed install with nrc7292 feed + setup script
# (see Makefile changes in CHANGES-FROM-STOCK-AREDN.md)

# Build
make TARGET=imx-cortexa7-nrc7292 MAKE_ARGS="-j$(nproc)"

# Package as stock-format .bin
python3 scripts/package_firmware.py \
    openwrt/bin/targets/imx/cortexa7/*-zImage \
    openwrt/build_dir/target-*/linux-imx_cortexa7/image-imx6ull-ap100ah.dtb \
    openwrt/bin/targets/imx/cortexa7/*-rootfs.squashfs \
    APBR-100-aredn.bin
```

## Upstream References

- [aredn/aredn](https://github.com/aredn/aredn) — AREDN firmware (tag 4.26.7.0)
- [aredn/aredn_packages](https://github.com/aredn/aredn_packages) — AREDN packages
- [newracom/nrc7292_sw_pkg](https://github.com/newracom/nrc7292_sw_pkg) — NRC7292 driver SDK
- [openwrt/openwrt](https://github.com/openwrt/openwrt) — OpenWrt v25.12.5
- [barberd/openwrt-silex-ap100ah](https://github.com/barberd/openwrt-silex-ap100ah) — Plain OpenWrt for AP-100AH

## License

- AREDN components: GPL-2.0
- NRC7292 driver: ISC License (Newracom)
- Build scripts and device integration: MIT
