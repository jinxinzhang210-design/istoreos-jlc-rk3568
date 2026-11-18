
# ---------------------------------------------------------------------------
# JLC RK3568 8125 custom board (RTL8125 2.5GbE)
# Append this block to target/linux/rockchip/image/armv8.mk
#
# - Reuses NanoPi R5S U-Boot: the donor image boots with rk3568-nanopi-r5s.dtb
#   in both idbloader and u-boot.itb, so the SPL stage is already compatible.
# - Supplies its own kernel DTB, decompiled from jlc_rk3568_8125.img.
# - Image/Build/dtb compiles ../dts/rk3568/rk3568-jlc-custom.dts into
#   $(KDIR)/image-rk3568-jlc-custom.dtb, which KERNEL embeds into the FIT.
# ---------------------------------------------------------------------------
define Device/jlc_rk3568_8125
  DEVICE_VENDOR := JLC
  DEVICE_MODEL := RK3568-8125
  SOC := rk3568
  DEVICE_DTS_DIR := ../dts
  DEVICE_DTS := rk3568/rk3568-jlc-custom
  KERNEL = kernel-bin | lzma | fit lzma $$(KDIR)/image-rk3568-jlc-custom.dtb
  UBOOT_DEVICE_NAME := nanopi-r5s-rk3568
  DEVICE_PACKAGES := kmod-r8169
  SUPPORTED_DEVICES := jlc,rk3568-custom
endef
TARGET_DEVICES += jlc_rk3568_8125
