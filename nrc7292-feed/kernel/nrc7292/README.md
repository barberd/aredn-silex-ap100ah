# NRC7292 Kernel Driver

The driver source is NOT included in this repo. It must be obtained from the
Newracom NRC7292 SDK and patched before building.

## Source: https://github.com/newracom/nrc7292_sdk

## Setup

```bash
# Clone the SDK
git clone https://github.com/newracom/nrc7292_sdk.git /tmp/nrc7292_sdk

# Copy driver source into this directory
cp /tmp/nrc7292_sdk/package/src/nrc/*.c src/
cp /tmp/nrc7292_sdk/package/src/nrc/*.h src/
cp /tmp/nrc7292_sdk/package/src/nrc/Makefile src/
cp /tmp/nrc7292_sdk/package/src/nrc/Kconfig src/
cp /tmp/nrc7292_sdk/package/src/nrc/nrc.lds src/

# Apply patches
cd src
patch -p1 < ../patches/001-phy-name-null.patch
patch -p1 < ../patches/002-disable-s1g-channel.patch
```

## Patches

- `001-phy-name-null.patch` — Register phy as `phy0` (kernel auto-assigns) instead of `nrc80211`, for compatibility with AREDN's node-setup which expects standard phy naming.
- `002-disable-s1g-channel.patch` — Disable native S1G channel mode. The driver uses channel remapping (presents as 2.4/5GHz to the OS) instead of kernel S1G support which isn't available in the mac80211 backports.
