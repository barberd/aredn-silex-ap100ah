#!/bin/bash
# setup-ap100ah.sh - Install AP-100AH specific files into AREDN's OpenWrt tree
# Run after OpenWrt clone but before build
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOP_DIR="$(dirname "$SCRIPT_DIR")"
OPENWRT="$TOP_DIR/openwrt"

echo "=== Installing AP-100AH support into OpenWrt tree ==="

# 1. Device Tree
echo "[1/8] Installing DTS..."
DTS_DIR="$OPENWRT/target/linux/imx/files/arch/arm/boot/dts/nxp/imx"
mkdir -p "$DTS_DIR"
cp "$TOP_DIR/nrc7292-feed/target-files/imx6ull-ap100ah.dts" "$DTS_DIR/"
echo "  -> $DTS_DIR/imx6ull-ap100ah.dts"

# 2. Device Profile (cortexa7.mk)
echo "[2/8] Installing device profile..."
cp "$TOP_DIR/nrc7292-feed/target-files/cortexa7.mk" "$OPENWRT/target/linux/imx/image/cortexa7.mk"
echo "  -> target/linux/imx/image/cortexa7.mk"

# 3. Kernel config additions
echo "[3/8] Installing kernel config additions..."
if ! grep -q "AP-100AH" "$OPENWRT/target/linux/imx/cortexa7/config-default" 2>/dev/null; then
    cat "$TOP_DIR/nrc7292-feed/target-files/config-default-additions" >> "$OPENWRT/target/linux/imx/cortexa7/config-default"
    echo "  -> Appended to target/linux/imx/cortexa7/config-default"
else
    echo "  -> Already present, skipping"
fi

# 4. wifi-scripts patches for NRC7292
echo "[4/8] Applying wifi-scripts patches for NRC7292..."
HOSTAPD_UC="$OPENWRT/package/network/config/wifi-scripts/files-ucode/usr/share/ucode/wifi/hostapd.uc"
if [ -f "$HOSTAPD_UC" ] && ! grep -q "nrc7292" "$HOSTAPD_UC" 2>/dev/null; then
    sed -i '/^function device_cell_density_append(config)/a\\t/* Skip rate configuration for NRC7292 HaLow radio */\n\treturn;' "$HOSTAPD_UC"
    sed -i '/^function device_rates(config)/a\\t/* Skip rate configuration for NRC7292 HaLow radio */\n\treturn;' "$HOSTAPD_UC"
    echo "  -> Patched hostapd.uc (skip rates)"
else
    echo "  -> hostapd.uc already patched or not found, skipping"
fi

MAC80211_SH="$OPENWRT/package/network/config/wifi-scripts/files-ucode/lib/netifd/wireless/mac80211.sh"
if [ -f "$MAC80211_SH" ] && ! grep -q "nrc7292" "$MAC80211_SH" 2>/dev/null; then
    sed -i 's|system(`iw phy ${phy} set antenna ${config.txantenna} ${config.rxantenna}`);|/* NRC7292: skip antenna */ // system(`iw phy ${phy} set antenna ${config.txantenna} ${config.rxantenna}`);|' "$MAC80211_SH"
    sed -i 's|system(`iw phy ${phy} set distance ${config.distance}`);|/* NRC7292: skip distance */ // system(`iw phy ${phy} set distance ${config.distance}`);|' "$MAC80211_SH"
    echo "  -> Patched mac80211.sh (skip antenna/distance)"
else
    echo "  -> mac80211.sh already patched or not found, skipping"
fi

# 5. Platform upgrade script (sysupgrade support)
echo "[5/8] Installing platform.sh..."
cp "$TOP_DIR/nrc7292-feed/target-files/platform.sh" "$OPENWRT/target/linux/imx/cortexa7/base-files/lib/upgrade/platform.sh"
echo "  -> target/linux/imx/cortexa7/base-files/lib/upgrade/platform.sh"

# 6. motd with channel mapping table
echo "[6/8] Installing motd..."
mkdir -p "$OPENWRT/files/etc"
cp "$TOP_DIR/nrc7292-feed/target-files/motd" "$OPENWRT/files/etc/motd" 2>/dev/null || echo "  -> No motd file, skipping"

# 7. LED configuration (uci-defaults, runs on first boot)
echo "[7/8] Installing LED config..."
mkdir -p "$OPENWRT/target/linux/imx/cortexa7/base-files/etc/uci-defaults"
cp "$TOP_DIR/nrc7292-feed/target-files/15_leds" "$OPENWRT/target/linux/imx/cortexa7/base-files/etc/uci-defaults/15_leds"
chmod +x "$OPENWRT/target/linux/imx/cortexa7/base-files/etc/uci-defaults/15_leds"
echo "  -> target/linux/imx/cortexa7/base-files/etc/uci-defaults/15_leds"

# 8. radios.json device entry (radio name, HaLow band, external antenna list)
echo "[8/8] Merging radios.json device entry..."
RADIOS_JSON="$OPENWRT/files/etc/radios.json"
ENTRY_JSON="$TOP_DIR/nrc7292-feed/target-files/radios-entry.json"
if [ -f "$RADIOS_JSON" ] && [ -f "$ENTRY_JSON" ]; then
    python3 - "$RADIOS_JSON" "$ENTRY_JSON" <<'PYEOF'
import json, sys
radios_path, entry_path = sys.argv[1], sys.argv[2]
with open(radios_path) as f:
    radios = json.load(f)
with open(entry_path) as f:
    entry = json.load(f)
radios.update(entry)
with open(radios_path, "w") as f:
    json.dump(radios, f, indent=4)
PYEOF
    echo "  -> Merged 'silex ap-100ah' into files/etc/radios.json"
else
    echo "  -> radios.json or entry file missing; skipping (add entry from radios-entry.json manually)"
fi

echo ""
echo "=== AP-100AH setup complete ==="
