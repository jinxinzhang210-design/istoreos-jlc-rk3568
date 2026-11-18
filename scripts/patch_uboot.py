#!/usr/bin/env python3
# ---------------------------------------------------------------------------
# Add our new device to the BUILD_DEVICES list of U-Boot/nanopi-r5s-rk3568.
#
# Why: in include/u-boot.mk, a U-Boot package is only DEFAULT:=y when the
# selected device matches one of its BUILD_DEVICES symbols. Our new device
# (jlc_rk3568_8125) is not listed, so u-boot-nanopi-r5s-rk3568 would not be
# built, and target/linux/rockchip/image/Makefile's pine64-img would fail with
# "dd: ... nanopi-r5s-rk3568-u-boot-rockchip.bin: No such file".
#
# Idempotent. Normalises line endings to LF. Exits non-zero on malformed input.
# ---------------------------------------------------------------------------
import sys

def main():
    if len(sys.argv) != 3:
        print("usage: patch_uboot.py <uboot-rockchip/Makefile> <device>", file=sys.stderr)
        return 2

    path, device = sys.argv[1], sys.argv[2]
    with open(path, "r", encoding="utf-8", newline="") as f:
        lines = f.read().replace("\r\n", "\n").replace("\r", "\n").split("\n")

    # locate the exact U-Boot/<name> block
    start = None
    for i, l in enumerate(lines):
        if l.strip() == "define U-Boot/nanopi-r5s-rk3568":
            start = i
            break
    if start is None:
        print("ERROR: 'define U-Boot/nanopi-r5s-rk3568' not found", file=sys.stderr)
        return 1

    end = None
    for j in range(start + 1, len(lines)):
        if lines[j].strip() == "endef":
            end = j
            break
    if end is None:
        print("ERROR: matching 'endef' not found", file=sys.stderr)
        return 1

    block = lines[start:end + 1]
    if any(device in l for l in block):
        print("BUILD_DEVICES already contains %s (nothing to do)" % device)
        return 0

    # append to the BUILD_DEVICES continuation list
    target_idx = None
    for k, l in enumerate(block):
        if l.strip() == "friendlyarm_nanopi-r5s":
            target_idx = start + k
            break
    if target_idx is None:
        print("ERROR: 'friendlyarm_nanopi-r5s' entry not found in the block", file=sys.stderr)
        return 1

    indent = lines[target_idx][:len(lines[target_idx]) - len(lines[target_idx].lstrip())]
    lines[target_idx] = "%sfriendlyarm_nanopi-r5s \\" % indent
    lines.insert(target_idx + 1, "%s%s" % (indent, device))

    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print("BUILD_DEVICES += %s (U-Boot/nanopi-r5s-rk3568)" % device)
    return 0

if __name__ == "__main__":
    sys.exit(main())
