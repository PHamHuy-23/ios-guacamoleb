#!/bin/bash
# Build the GM1901 (OnePlus 7, SM8150) bare-metal shim and package boot images:
#   - out/shim-boot.img     : Android boot header v2 (dtb_offset 0x1f00000, matches Evolution X / OOS 11-12)
#   - out/shim-boot-oos.img : Android boot header v1 + 20-byte UNCOMPRESSED_IMG prefix + appended DTB (matches stock OOS 9/10)
# Works on both Linux (aarch64-linux-gnu-gcc) and macOS (Xcode clang -target aarch64-none-elf + Python linker/packer).
set -euo pipefail
cd "$(dirname "$0")"
CFLAGS="-O2 -ffreestanding -nostdlib -fno-pic -mgeneral-regs-only -mstrict-align -fno-stack-protector -Wall -Wextra"
mkdir -p out

if command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
	CC="aarch64-linux-gnu-gcc"
	for f in start.S shim.c console.c mmu.c fdt.c loader.c ufs.c; do
		$CC $CFLAGS -c "$f" -o "out/${f%.*}.o"
	done
	abs=$(aarch64-linux-gnu-readelf -r out/shim.o out/console.o out/mmu.o out/fdt.o out/loader.o out/ufs.o | grep -c ABS64 || true)
	[ "$abs" = 0 ] || { echo "error: $abs absolute relocations in C objects" >&2; exit 1; }
	$CC $CFLAGS -static -T shim.ld -Wl,--build-id=none -Wl,--no-warn-rwx-segments -Wl,-N \
		out/start.o out/shim.o out/console.o out/mmu.o out/fdt.o out/loader.o out/ufs.o -o out/shim.elf
	aarch64-linux-gnu-objcopy -O binary out/shim.elf out/Image
	size=$(aarch64-linux-gnu-nm out/shim.elf | awk '$3=="_end"{print strtonum("0x"$1)}')
	truncate -s "$size" out/Image
else
	CC="clang -target aarch64-none-elf"
	for f in start.S shim.c console.c mmu.c fdt.c loader.c ufs.c; do
		$CC $CFLAGS -c "$f" -o "out/${f%.*}.o"
	done
	python3 - <<'PY'
import struct, sys

objs = ["out/start.o", "out/shim.o", "out/console.o", "out/mmu.o", "out/fdt.o", "out/loader.o", "out/ufs.o"]

def align(v, a):
    return (v + a - 1) & ~(a - 1) if a > 1 else v

class Obj:
    def __init__(self, path):
        self.path = path
        self.data = open(path, "rb").read()
        e_shoff, e_shentsize, e_shnum, e_shstrndx = struct.unpack_from("<Q10xHHH", self.data, 40)
        self.shdrs = [struct.unpack_from("<IIQQQQIIQQ", self.data, e_shoff + i * e_shentsize) for i in range(e_shnum)]
        shstr_off, shstr_sz = self.shdrs[e_shstrndx][4], self.shdrs[e_shstrndx][5]
        shstr = self.data[shstr_off:shstr_off + shstr_sz]
        self.sec_names = [shstr[s[0]:shstr.find(b"\x00", s[0])].decode() for s in self.shdrs]
        self.sec_vma = {}
        self.syms = []
        self.strtab = b""
        for i, s in enumerate(self.shdrs):
            if s[1] == 2: # SHT_SYMTAB
                str_s = self.shdrs[s[6]]
                self.strtab = self.data[str_s[4]:str_s[4] + str_s[5]]
                for off in range(s[4], s[4] + s[5], 24):
                    st_name, st_info, st_other, st_shndx, st_value, st_size = struct.unpack_from("<IBBHQQ", self.data, off)
                    name = self.strtab[st_name:self.strtab.find(b"\x00", st_name)].decode() if st_name else ""
                    self.syms.append((name, st_info, st_shndx, st_value, st_size))

parsed = [Obj(p) for p in objs]
image = bytearray()

def append_secs(pred):
    for o in parsed:
        for i, s in enumerate(o.shdrs):
            sh_type, sh_flags, _, sh_offset, sh_size, _, _, sh_addralign, _ = s[1], s[2], s[3], s[4], s[5], s[6], s[7], s[8], s[9]
            if not (sh_flags & 2) or sh_type == 8: # Must be SHF_ALLOC and not SHT_NOBITS
                continue
            if pred(o.sec_names[i]):
                pad = align(len(image), max(1, sh_addralign)) - len(image)
                image.extend(b"\x00" * pad)
                o.sec_vma[i] = len(image)
                image.extend(o.data[sh_offset:sh_offset + sh_size])

# Layout matching shim.ld: .text.head, .text*, .rodata*, .data*, .bss*
append_secs(lambda n: n == ".text.head")
append_secs(lambda n: n == ".text" or (n.startswith(".text.") and n != ".text.head"))
append_secs(lambda n: n == ".rodata" or n.startswith(".rodata."))
append_secs(lambda n: n == ".data" or n.startswith(".data."))

file_bytes_end = len(image)
cur = align(len(image), 16)
bss_start = cur
for o in parsed:
    for i, s in enumerate(o.shdrs):
        if (s[2] & 2) and s[1] == 8: # SHF_ALLOC and SHT_NOBITS (.bss)
            cur = align(cur, max(1, s[8]))
            o.sec_vma[i] = cur
            cur += s[5]
bss_end = align(cur, 16)
stack_top = align(bss_end + 0x8000, 16)
sec_stacks = align(stack_top, 4096)
img_end = sec_stacks + 8 * 0x1000
image.extend(b"\x00" * (img_end - len(image)))

globals_vma = {
    "_bss_start": bss_start,
    "_bss_end": bss_end,
    "_stack_top": stack_top,
    "_sec_stacks": sec_stacks,
    "_end": img_end,
}
for o in parsed:
    for name, st_info, st_shndx, st_value, _ in o.syms:
        bind = st_info >> 4
        if bind in (1, 2) and st_shndx != 0 and st_shndx < len(o.shdrs):
            if st_shndx in o.sec_vma:
                globals_vma[name] = o.sec_vma[st_shndx] + st_value

# Apply relocations and verify no ABS64 in C objects
for o in parsed:
    for i, s in enumerate(o.shdrs):
        if s[1] != 4: # SHT_RELA
            continue
        target_sec = s[7]
        if target_sec not in o.sec_vma:
            continue
        sec_base = o.sec_vma[target_sec]
        for off in range(s[4], s[4] + s[5], 24):
            r_offset, r_info, r_addend = struct.unpack_from("<QQq", o.data, off)
            r_type = r_info & 0xffffffff
            r_sym = r_info >> 32
            sym_name, sym_info, sym_shndx, sym_val, _ = o.syms[r_sym]
            if sym_shndx == 0:
                if sym_name not in globals_vma:
                    sys.exit(f"error: undefined symbol {sym_name} in {o.path}")
                S = globals_vma[sym_name]
            else:
                S = o.sec_vma[sym_shndx] + sym_val
            P = sec_base + r_offset
            val = S + r_addend
            if r_type == 257: # R_AARCH64_ABS64
                if o.path != "out/start.o":
                    sys.exit(f"error: ABS64 relocation in C object {o.path} at 0x{r_offset:x}")
                struct.pack_into("<Q", image, P, val)
            elif r_type == 274: # R_AARCH64_ADR_PREL_LO21
                imm = val - P
                insn = struct.unpack_from("<I", image, P)[0] & 0x9f00001f
                insn |= ((imm & 3) << 29) | (((imm >> 2) & 0x7ffff) << 5)
                struct.pack_into("<I", image, P, insn)
            elif r_type == 275: # R_AARCH64_ADR_PREL_PG_HI21
                imm = ((val & ~0xfff) - (P & ~0xfff)) >> 12
                insn = struct.unpack_from("<I", image, P)[0] & 0x9f00001f
                insn |= ((imm & 3) << 29) | (((imm >> 2) & 0x7ffff) << 5)
                struct.pack_into("<I", image, P, insn)
            elif r_type == 277: # R_AARCH64_ADD_ABS_LO12_NC
                insn = struct.unpack_from("<I", image, P)[0] & 0xffc003ff
                insn |= (val & 0xfff) << 10
                struct.pack_into("<I", image, P, insn)
            elif r_type in (278, 285, 286): # LDST8 (278), LDST32 (285), LDST64 (286)
                shift = 0 if r_type == 278 else (2 if r_type == 285 else 3)
                insn = struct.unpack_from("<I", image, P)[0] & 0xffc003ff
                insn |= ((val & 0xfff) >> shift) << 10
                struct.pack_into("<I", image, P, insn)
            elif r_type in (282, 283): # R_AARCH64_JUMP26, R_AARCH64_CALL26
                imm = (val - P) >> 2
                insn = struct.unpack_from("<I", image, P)[0] & 0xfc000000
                insn |= imm & 0x03ffffff
                struct.pack_into("<I", image, P, insn)
            else:
                sys.exit(f"error: unsupported relocation type {r_type} in {o.path}")

open("out/Image", "wb").write(image)
print(f"Linked out/Image: {len(image)} bytes (_bss_start=0x{bss_start:x}, _end=0x{img_end:x})")
PY
fi

# Ramdisk: an xnu payload (tools/mkpayload.py) if given as $1, else an empty
# newc cpio (ABL dislikes a zero-size ramdisk on some builds) -> diagnostics.
if [ -n "${1:-}" ]; then
	cp "$1" out/ramdisk.bin
else
	(cd out && rm -rf rd && mkdir rd && cd rd && find . | cpio -o -H newc --quiet | gzip -9 > ../ramdisk.bin)
fi

# Package GM1901 boot images:
#   1. out/shim-boot.img     (Android boot header v2, dtb_offset 0x1f00000 — Evolution X / OOS 11-12)
#   2. out/shim-boot-oos.img (Android boot header v1 + UNCOMPRESSED_IMG + appended DTB — Stock OOS 9/10)
python3 - <<'PY'
import os, struct

img = open("out/Image", "rb").read()
ramdisk = open("out/ramdisk.bin", "rb").read()

def pad_page(b, ps=4096):
    rem = len(b) % ps
    return b + (b"\x00" * (ps - rem) if rem else b"")

# Extract GM1901 DTBs from local firmware images if available
oos_dtb = b""
if os.path.exists("../default-img/OnePlus7Oxygen_14.O.11_OTA_011_all_1906072127_boot.img"):
    with open("../default-img/OnePlus7Oxygen_14.O.11_OTA_011_all_1906072127_boot.img", "rb") as f:
        hdr = f.read(4096)
        ks = struct.unpack_from("<I", hdr, 8)[0]
        kblob = f.read(ks)
        if kblob.startswith(b"UNCOMPRESSED_IMG"):
            klen = struct.unpack_from("<I", kblob, 16)[0]
            oos_dtb = kblob[20 + klen:]
elif os.path.exists("../dtb/boot_unpacked/dtb"):
    oos_dtb = open("../dtb/boot_unpacked/dtb", "rb").read()

evox_dtb = oos_dtb
if os.path.exists("../evolutionX-rom/boot.img"):
    with open("../evolutionX-rom/boot.img", "rb") as f:
        hdr = f.read(4096)
        ks, _, rs = struct.unpack_from("<III", hdr, 8)
        rec_sz, rec_off, _, dtb_sz, _ = struct.unpack_from("<IQIIQ", hdr, 1632)
        if dtb_sz > 0:
            dtb_file_off = rec_off + ((rec_sz + 4095) & ~4095)
            f.seek(dtb_file_off)
            evox_dtb = f.read(dtb_sz)

if not evox_dtb and not oos_dtb:
    raise SystemExit("error: no GM1901 DTB found in ../default-img/, ../evolutionX-rom/, or ../dtb/")
if not oos_dtb:
    oos_dtb = evox_dtb

# 1. Build out/shim-boot.img (boot header v2, dtb_offset 0x1f00000)
hdr_v2 = bytearray(4096)
hdr_v2[0:8] = b"ANDROID!"
# kernel_size, kernel_addr, ramdisk_size, ramdisk_addr, second_size, second_addr, tags_addr, page_size, header_version, os_version
struct.pack_into("<10I", hdr_v2, 8,
    len(img), 0x00008000,
    len(ramdisk), 0x01000000,
    0, 0x00000000,
    0x00000100, 4096, 2, 0x200001a4)
cmdline_v2 = b"androidboot.hardware=qcom androidboot.console=ttyMSM0 androidboot.memcg=1 lpm_levels.sleep_disabled=1 msm_rtb.filter=0x237 service_locator.enable=1 swiotlb=2048 firmware_class.path=/vendor/firmware_mnt/image loop.max_part=7 androidboot.usbcontroller=a600000.dwc3"
hdr_v2[64:64+len(cmdline_v2)] = cmdline_v2
struct.pack_into("<IQIIQ", hdr_v2, 1632, 0, 0, 1660, len(evox_dtb), 0x01f00000)
with open("out/shim-boot.img", "wb") as f:
    f.write(hdr_v2)
    f.write(pad_page(img))
    f.write(pad_page(ramdisk))
    f.write(pad_page(evox_dtb))

# 2. Build out/shim-boot-oos.img (Stock OOS boot header v1 + UNCOMPRESSED_IMG + appended DTB)
oos_kernel = b"UNCOMPRESSED_IMG" + struct.pack("<I", len(img)) + img + oos_dtb
hdr_v1 = bytearray(4096)
hdr_v1[0:8] = b"ANDROID!"
struct.pack_into("<10I", hdr_v1, 8,
    len(oos_kernel), 0x00008000,
    len(ramdisk), 0x01000000,
    0, 0x00f00000,
    0x00000100, 4096, 1, 0x12000135)
cmdline_v1 = b"androidboot.hardware=qcom androidboot.console=ttyMSM0 androidboot.memcg=1 lpm_levels.sleep_disabled=1 msm_rtb.filter=0x237 service_locator.enable=1 swiotlb=2048 androidboot.usbcontroller=a600000.dwc3"
hdr_v1[64:64+len(cmdline_v1)] = cmdline_v1
struct.pack_into("<IQI", hdr_v1, 1632, 0, 0, 1648)
with open("out/shim-boot-oos.img", "wb") as f:
    f.write(hdr_v1)
    f.write(pad_page(oos_kernel))
    f.write(pad_page(ramdisk))
PY

# Host render of the console layout (1080x2340).
gcc -O1 -Wall -o out/host_test console.c host_test.c && ./out/host_test
ls -lh out/Image out/shim-boot.img out/shim-boot-oos.img
