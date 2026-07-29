#!/usr/bin/env python3
"""
Package OpenWrt build output into AP-100AH firmware format.

Takes: zImage, DTB, rootfs.squashfs
Produces: APBR-100-openwrt.bin (signed, ready to flash via web UI)
"""
import hmac
import hashlib
import tarfile
import sys
import os
from io import BytesIO

KEY = bytes.fromhex('5e561517291bf48b7f9e80f69f79a33c6f7b8fab')

UPDATE_SH = b"""#!/bin/sh

#
# Firmware update script
# Model: APBR-100
# ROM: winbond support
#

case "$1" in
  start)
\t;;
  *)
\t;;
esac
"""

def sign_firmware(data: bytes) -> bytes:
    """PKCS#7 pad + HMAC-SHA1 sign"""
    pad_len = (256 - ((len(data) + 20) % 256)) % 256
    if pad_len == 0:
        pad_len = 256
    padded = data + bytes([pad_len & 0xFF] * pad_len)
    sig = hmac.new(KEY, padded, hashlib.sha1).digest()
    return padded + sig


def build_firmware(zimage_path, dtb_path, rootfs_path, output_path):
    """Create signed firmware .bin"""
    
    # Verify inputs exist
    for path in [zimage_path, dtb_path, rootfs_path]:
        if not os.path.exists(path):
            print(f"ERROR: {path} not found")
            sys.exit(1)
    
    # Size checks
    dtb_size = os.path.getsize(dtb_path)
    kernel_size = os.path.getsize(zimage_path)
    rootfs_size = os.path.getsize(rootfs_path)
    
    print(f"DTB:    {dtb_size:>10} bytes ({dtb_path})")
    print(f"Kernel: {kernel_size:>10} bytes ({zimage_path})")
    print(f"Rootfs: {rootfs_size:>10} bytes ({rootfs_path})")
    print()
    
    # Safety checks
    if dtb_size > 64 * 1024:
        print(f"WARNING: DTB ({dtb_size}) exceeds mtd2 size (65536)!")
    if kernel_size > 3 * 1024 * 1024:
        print(f"WARNING: Kernel ({kernel_size}) exceeds mtd3 size (3145728)!")
    if rootfs_size > 27.6 * 1024 * 1024:
        print(f"WARNING: Rootfs ({rootfs_size}) exceeds mtd5 size (~28835840)!")
    
    # Create tar.bz2 in memory
    buf = BytesIO()
    with tarfile.open(fileobj=buf, mode='w:bz2') as tar:
        # update.sh
        info = tarfile.TarInfo(name='update.sh')
        info.size = len(UPDATE_SH)
        info.mode = 0o755
        tar.addfile(info, BytesIO(UPDATE_SH))
        
        # DTB
        tar.add(dtb_path, arcname='imx6ull-sx.dtb')
        
        # Kernel
        tar.add(zimage_path, arcname='zImage')
        
        # Root filesystem
        tar.add(rootfs_path, arcname='rootfs.squashfs')
    
    tar_data = buf.getvalue()
    print(f"tar.bz2: {len(tar_data)} bytes")
    
    # Sign
    signed = sign_firmware(tar_data)
    
    with open(output_path, 'wb') as f:
        f.write(signed)
    
    print(f"Output:  {len(signed)} bytes → {output_path}")
    print(f"HMAC:    {signed[-20:].hex()}")


if __name__ == '__main__':
    if len(sys.argv) < 4:
        print(f"Usage: {sys.argv[0]} <zImage> <dtb> <rootfs.squashfs> [output.bin]")
        sys.exit(1)
    
    output = sys.argv[4] if len(sys.argv) > 4 else 'APBR-100-openwrt.bin'
    build_firmware(sys.argv[1], sys.argv[2], sys.argv[3], output)
