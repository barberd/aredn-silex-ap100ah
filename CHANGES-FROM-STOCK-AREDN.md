# Changes from Stock AREDN 4.26.7.0

This document describes all modifications made to the AREDN 4.26.7.0 release to support the Silex AP-100AH with the Newracom NRC7292 802.11ah (HaLow) radio.

## OpenWrt / Kernel / Driver Changes

### NRC7292 Kernel Driver (kmod-nrc7292)

**Phy naming** (`nrc-init.c`):
- Pass `NULL` to `ieee80211_alloc_hw_nm()` instead of `NRC_DRIVER_NAME`
- Reason: AREDN's `node-setup` iterates phys as `phy0`, `phy1`, etc. The driver originally registered as `nrc80211` which `node-setup` couldn't find, resulting in empty `/etc/config/wireless`.

**Disable CONFIG_S1G_CHANNEL** (`nrc-build-config.h`):
- `/* #define CONFIG_S1G_CHANNEL */` (commented out)
- Reason: The NRC7292 uses channel remapping (presents as standard 2.4/5GHz radio). The native S1G code paths reference kernel defines (`IEEE80211_CHAN_1MHZ`, etc.) that don't exist in the mac80211 backports.

### Kernel Configuration

**802.1Q VLAN built-in** (`config-default-additions`):
- `CONFIG_VLAN_8021Q=y` (built-in, not module)
- Reason: AREDN's bridge VLAN filtering requires 802.1Q at boot. As a module it wasn't being loaded, preventing `br0.X` VLAN sub-interfaces from being created.

### Device Tree (`imx6ull-ap100ah.dts`)

- NRC7292 on ecspi4 (SPI interface with GPIO reset/IRQ)
- QSPI NOR flash with fixed MTD partitions (u-boot, env, fdt, kernel, data, rootfs)
- FEC ethernet with RMII PHY
- GPIO LEDs (power orange, wifi yellow, lan green)
- 128MB memory (correct, stock DTB said 512MB)
- Bootargs in chosen node

### Device Profile (`cortexa7.mk`)

- Added `silex_ap-100ah` device definition
- zImage output, squashfs filesystem
- sysupgrade-tar image format

### Board Detection (`02_network` via quilt patch `810-define-aredn-imx-networks.patch`)

- Single-port AREDN VLAN layout: `lan: eth0`, `wan: eth0.1`, `dtdlink: eth0.2`, `wifi: wlan0`
- Without this, board.json defaults to `wan: eth1` which doesn't exist.

### Platform Sysupgrade (`platform.sh`)

- Added `silex,ap-100ah` with `mtd write` for kernel and rootfs partitions
- Handles optional DTB member in sysupgrade tar
- Stock imx target only supported TechNexion Pico-Pi (SD card)

### LED Configuration (`uci-defaults/15_leds`)

- Configures LED triggers on first boot: LAN LED on eth0 activity, WiFi LED on wlan0 activity
- Power LED always on via DTS `default-state`

### NRC7292 Init Script (`nrc7292-init`)

- `START=50` (runs before `aredn_init` at S55)
- Waits for phy directory (`/sys/class/ieee80211/phy0`) instead of `wlan0`
- No failure return (warns instead) — `wlan0` is created later by wifi-scripts
- GPIO 28 reset sequence + insmod with SPI parameters

### wifi-scripts (`mac80211.sh`)

- Re-applied AREDN's `712-mac80211.patch` `has_sta`/`has_ap` guards
- Without these, `hostapd.setup()` is called for adhoc mode, hangs waiting for a non-existent daemon, netifd times out after 30 seconds, and tears down the radio in a loop

## AREDN Application Changes

### Channel Mapping (`/etc/nrc7292-channels.json`)

New file — JSON lookup table mapping fake frequencies reported by the NRC7292 driver to real 900MHz HaLow frequencies:

```json
{
  "2412": { "freq": 902.5, "bw": 1, "s1g_ch": 1 },
  "5180": { "freq": 908.5, "bw": 1, "s1g_ch": 13 },
  "5745": { "freq": 921.5, "bw": 1, "s1g_ch": 39 },
  ...
}
```

Keyed by fake frequency (MHz), contains real frequency, bandwidth (MHz), and S1G channel number.

### hardware.uc — Frequency Display

**`getWiFiChannels()` — NRC7292 combined-band freq_adjust**:
- Combines ALL bands (2GHz + 5GHz) since both are fake
- Loads `/etc/nrc7292-channels.json` to map fake→real frequencies
- Filters to 902-928 MHz range
- Detection: `index(radioname, "NRC7292") !== -1`
- Follows same pattern as M9 (`-1520` offset) and M3 (`-2000` offset)

**`getChannelFromRadioFrequency()` — S1G channel number formula**:
- Added `if (freq >= 902 && freq <= 928) return int((freq - 902.0) * 2);`
- Produces correct S1G channel numbers (1-51) from real 900MHz frequencies
- Placed before the existing `freq < 927` check which used the wrong M9 formula

**`getDefaultChannel()` — First channel detection**:
- Added check for `c.frequency == 908.5` → returns `{ channel: 13, bandwidth: 1, band: "HaLow" }`
- The 5GHz band (most channels) starts at 908.5 MHz after freq_adjust

**`getRfChannels()` — NRC7292 exclusion from Morse HaLow table**:
- `if (radio.band == "halow" && index(getRadioName(), "NRC7292") === -1)` uses Morse hardcoded table
- NRC7292 uses `getWiFiChannels()` with freq_adjust instead

### hardware.uc — De-coupling HaLow from Morse Micro

All Morse-specific operations gated on actual Morse hardware presence, not just `"halow"` radio type:

**`getRadioNoise()`**:
- `morse_cli` only called when `/sys/kernel/debug/ieee80211/{phy}/morse` exists
- Non-Morse halow defaults to -95 dBm

**`getMaxDistance()`**:
- `morse_cli get ack_timeout_adjust` only called when morse debugfs exists
- Non-Morse halow returns -1 (unsupported)

**`setMaxDistance()`**:
- `morse_cli set ack_timeout_adjust` only called when morse debugfs exists
- Non-Morse halow returns -1 (unsupported)

### wireless_monitor.uc — Prevent false reboot/restart

**Reboot check (line 287)**:
- Original: reboots if halow radio type but no `/morse` debugfs (assumes Morse crashed)
- Fixed: only reboots if device has `bcf` field in radios.json (actual Morse hardware)
- Pattern: `hardware.getRadioIntf(wifi)?.bcf && !fs.access(.../morse)`

**Station restart check (line 319)**:
- Original: restarts radio if halow with no stations (assumes Morse needs kick)
- Fixed: same `bcf` gate — only applies to actual Morse devices

### node-setup — Channel Translation (Reverse Mapping)

**S1G channel → fake channel for UCI wireless config**:
- Config stores real S1G channel numbers (for correct SSID: `AREDN-5-1-v3`)
- When writing `/etc/config/wireless`, looks up the fake channel/band from `nrc7292-channels.json`
- Pattern: search for entry matching `s1g_ch == channel && bw == chanbw`, derive fake channel number and band (2g/5g)

**HaLow case — skip Morse-specific settings**:
- `type = "morse"` only set if NRC7292 is NOT detected
- `phydev` and `bcf` only set for Morse
- Band written as `write_band` from lookup (2g/5g) instead of `'s1g'`

**chanbw validation workaround**:
- OpenWrt's validate.uc only accepts chanbw 5/10/20
- For NRC7292: writes `chanbw=20` to UCI (driver ignores it, bandwidth inherent to S1G channel)
- Real bandwidth stored in `radio0_bandwidth` for SSID generation

### radios.json — Device Entry

```json
"silex ap-100ah": {
    "name": "Silex AP-100AH (NRC7292 HaLow)",
    "wlan0": {
        "band": "halow",
        "bandwidths": [1, 2, 4],
        "exclude_modes": ["wan"],
        "maxpower": 23,
        "antenna": { "model": "Internal", "gain": 3, "beamwidth": 360 }
    },
    "features": ["xlink"],
    "timeouts": { "reboot": [60, 300], "upgrade": [240, 720] }
}
```

- `band: "halow"` — enables halow UI behavior (channel in SSID, polarization, bandwidth selector)
- `bandwidths: [1, 2, 4]` — S1G HaLow bandwidths (not standard WiFi 5/10/20)
- No `bcf` field — this is how wireless_monitor distinguishes from Morse Micro

### radios.uc — Channel Availability Table

Updated HaLow `avail` arrays to include all US S1G channels:
- `"1"`: Added channels 1, 3, 51 (was starting at 5)
- `"2"`: Added channels 2, 50
- `"4"`: Added channel 48

### hardware.uc — Ethernet Ports

Added `silex,ap-100ah` to `getEthernetPorts()` returning `default1PortLayout` (single LAN port).

## Removed from Stock AREDN

### morse-feed

- Removed `src-git morse` from `feeds.conf`
- Commented out `790-morsemicro-support.patch` and `791-morsemicro-remove-patches.patch` from `patches/series`
- Removed morse feed install from Makefile
- Reason: Morse Micro's forked hostapd, wpa_supplicant, and netifd are for a completely different S1G implementation. Incompatible with NRC7292's channel-remapping approach.

## Design Decisions

### Why not use native S1G (`CONFIG_S1G_CHANNEL`)?
The NRC7292 driver's native S1G path requires kernel S1G defines that don't exist in OpenWrt's mac80211 backports. The channel-remapping approach (present as 2.4/5GHz, translate internally) works with stock hostapd/wpa_supplicant/netifd without modification.

### Why `band: "halow"` with custom `getRfChannels`?
Setting `band: "halow"` enables correct UI behavior (SSID format, channel selector, bandwidth options). But `getRfChannels()` bypasses the Morse hardcoded channel table for NRC7292, using nl80211 + freq_adjust instead. This allows the UI to show real frequencies from the actual hardware.

### Why gate on `bcf`/debugfs instead of radio name?
Future halow radios (not Morse, not NRC7292) will safely get default behavior without needing code changes. Only actual Morse hardware (identified by `bcf` field or `/morse` debugfs) runs Morse-specific commands.
