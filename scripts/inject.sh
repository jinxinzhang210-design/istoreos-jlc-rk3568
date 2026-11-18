#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Inject the JLC RK3568 8125 board support into the iStoreOS source tree.
#
# Runs on the GitHub Actions runner (ubuntu-22.04), called by the workflow.
# Idempotent: safe to re-run on a resumed build.
#
#   $1 = path to the cloned iStoreOS source (default: ./openwrt)
#
# What it does:
#   1. Copy the decompiled DTS into target/linux/rockchip/dts/rk3568/
#      (verified: 24.10 uses per-SoC subdirectories, so DEVICE_DTS must be
#       "rk3568/rk3568-jlc-custom" with DEVICE_DTS_DIR := ../dts)
#   2. Append the device profile to target/linux/rockchip/image/armv8.mk
#      (same pattern as upstream nanopi-r2s / nanopi-r4s custom-DTS devices)
#   3. Add jlc_rk3568_8125 to the BUILD_DEVICES of U-Boot/nanopi-r5s-rk3568
#      so the u-boot package is auto-selected and
#      $(STAGING_DIR_IMAGE)/nanopi-r5s-rk3568-u-boot-rockchip.bin exists
#      when pine64-img dd's it. Without this the image build fails.
#   4. Copy config.seed to .config
# ---------------------------------------------------------------------------
set -euo pipefail

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${1:-openwrt}"
DEVICE="jlc_rk3568_8125"
DTS="rk3568-jlc-custom"

echo "== inject: source=$SRC  kit=$KIT =="
[ -d "$SRC/target/linux/rockchip" ] || {
  echo "ERROR: $SRC does not look like an iStoreOS/OpenWrt tree"; exit 1; }
[ -f "$KIT/board/$DTS.dts" ] || { echo "ERROR: missing board/$DTS.dts"; exit 1; }

cd "$SRC"

# ---- 1. device tree source ------------------------------------------------
mkdir -p target/linux/rockchip/dts/rk3568
cp -f "$KIT/board/$DTS.dts" target/linux/rockchip/dts/rk3568/
# Keep the original extracted DTB alongside for reference / emergency fallback.
cp -f "$KIT/board/$DTS.dtb" target/linux/rockchip/dts/rk3568/
echo "DTS installed -> target/linux/rockchip/dts/rk3568/$DTS.dts"

# ---- 2. device profile ----------------------------------------------------
ARMV8="target/linux/rockchip/image/armv8.mk"
if grep -q "TARGET_DEVICES += $DEVICE" "$ARMV8"; then
  echo "device profile already present in $ARMV8"
else
  cat "$KIT/board/device-profile.mk" >> "$ARMV8"
  echo "device profile appended to $ARMV8"
fi

# ---- 3. u-boot BUILD_DEVICES (the non-obvious part) -----------------------
python3 "$KIT/scripts/patch_uboot.py" package/boot/uboot-rockchip/Makefile "$DEVICE"

# ---- 4. config seed -------------------------------------------------------
cp -f "$KIT/config.seed" .config
echo "config.seed -> .config"

# ---- 5. sanity dump -------------------------------------------------------
echo "---- armv8.mk tail ----"
tail -16 "$ARMV8"
echo "---- U-Boot/nanopi-r5s-rk3568 block ----"
sed -n '/define U-Boot\/nanopi-r5s-rk3568/,/^endef/p' package/boot/uboot-rockchip/Makefile
echo "---- .config target lines ----"
grep -E "^CONFIG_TARGET|^CONFIG_PACKAGE_u-boot" .config || true
echo "== inject: done =="
