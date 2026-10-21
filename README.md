# ios-sweet (Nhánh port cho OnePlus 7 — GM1901)

**Dự án port iOS 16 (XNU 8796 + userland iPhone X 16.7.16 `20H392`) sang OnePlus 7 (`GM1901` / `guacamoleb`, Qualcomm Snapdragon 855 / SM8150).**

Repository này xuất phát từ bản bring-up iOS 16.7.16 trên nền Qualcomm Snapdragon (`sweet` / SM7150 — đã khởi động lên màn hình chính iOS, cảm ứng, phím cứng, 8 nhân SMP và mạng USB CDC-ECM qua bản vá `0080`), và hiện được chuyển hướng sang thiết bị mục tiêu của máy bạn: **OnePlus 7 (`GM1901`, SM8150, bootloader đã mở khóa)**.

> **Tình trạng hiện tại (2026-10-21):**
> - **Đã hoàn tất giải nén firmware & dịch ngược driver của máy GM1901** từ ROM gốc OxygenOS (`OnePlus7Oxygen_14.O.11` / `14.O.22`) và Evolution X (`Android 16`), sử dụng công cụ tách DTB/DTBO (`dtb_02.dtb`, `dtbo_20.dtb` cho `project-id = 0x49a9` / `18857`), UEFI `LinuxLoader.efi` (`abl.img`) và **MCP REA** trên kernel `Image` của GM1901.
> - **Đã cập nhật bộ công cụ khởi động (`shim/` & `tools/mkadt.py`) sang thông số OnePlus 7 (`GM1901`):**
>   - [`shim/shim.c`](file:///Users/nguyendinhkhanh/Documents/GitHub/ios-sweet/shim/shim.c): cập nhật `IMEM_RESTART_REASON = 0x146bf65c` (`imem@146bf000 + 0x65c` trên SM8150).
>   - [`shim/console.h`](file:///Users/nguyendinhkhanh/Documents/GitHub/ios-sweet/shim/console.h): cập nhật độ phân giải framebuffer vật lý `1080×2340` (`FB_W = 1080`, `FB_H = 2340`, `FB_STRIDE = 4320`, `FB_BASE = 0x9c000000`).
>   - [`tools/mkadt.py`](file:///Users/nguyendinhkhanh/Documents/GitHub/ios-sweet/tools/mkadt.py): cập nhật framebuffer `1080×2340` (`36 MiB`), cấu hình 8 nhân `qcom,kryo485` (4 nhân Silver 1,78 GHz + 3 nhân Gold 2,42 GHz + 1 nhân Prime 2,84 GHz) và định danh `oneplus,gm1901` / `qcom,sm8150`.
>   - [`shim/build.sh`](file:///Users/nguyendinhkhanh/Documents/GitHub/ios-sweet/shim/build.sh): hỗ trợ biên dịch trực tiếp trên **macOS** (dùng `clang -target aarch64-none-elf`) lẫn **Linux** (`aarch64-linux-gnu-gcc`), tự động trích xuất DTB của GM1901 và đóng gói đồng thời 2 ảnh khởi động: `shim/out/shim-boot.img` (chuẩn Header v2 cho Evolution X / OOS 11–12) và `shim/out/shim-boot-oos.img` (chuẩn Header v1 + `UNCOMPRESSED_IMG` cho OxygenOS 9/10 gốc).
> - **Đã tạo và kiểm tra bản vá kernel XNU cho GM1901 ([`xnu/patches/0082-gm1901-drivers.patch`](file:///Users/nguyendinhkhanh/Documents/GitHub/ios-sweet/xnu/patches/0082-gm1901-drivers.patch)):** cập nhật trình điều khiển cảm ứng Synaptics S3706 RMI4 (`bsd/dev/sweet_touch.c`), nút cứng PM8150 SID 0 GPIO6/GPIO7 (`bsd/dev/sweet_keys.c`), nguồn `"ldoa17"` `3008` mV (`bsd/dev/sweet_rpmh.c`), clock GCC USB SM8150 (`bsd/dev/sweet_usb.c`), cùng chiều cao panel `2340` và cử chỉ vuốt cạnh dưới (`osfmk/arm64/sweet_early.c`, `iokit/Kernel/arm/hid/SweetHID.cpp`).
> - Đây là bản bring-up thử nghiệm. Khi cài đặt rootfs iOS vào phân vùng `userdata`, **toàn bộ dữ liệu người dùng Android sẽ bị xóa** (các phân vùng bootloader, recovery, modem, persist được giữ nguyên).

---

## Trạng thái các thành phần đối với OnePlus 7 (`GM1901` — SM8150)

| Hạng mục | Trạng thái trên nền tảng XNU hiện có | Tình trạng tương thích / Cổng chuyển sang OnePlus 7 (`GM1901`) |
| --- | --- | --- |
| **Khởi động (`shim/`)** | Bootloader Qualcomm ABL → `fastboot boot` shim → XNU Mach-O + ADT | **Đã cập nhật cho GM1901:** `IMEM_RESTART = 0x146bf65c`, màn hình `1080×2340`; `shim/build.sh` tự động tạo cả `shim-boot.img` (Header v2 cho Evolution X / OOS 11–12) và `shim-boot-oos.img` (Header v1 + `UNCOMPRESSED_IMG` cho OOS 9/10) |
| **GICv3 & Timer** | GICv3 (`GICD = 0x17a00000`, `GICR = 0x17a60000`, stride `0x20000`), timer 19,2 MHz (PPI 19) | **Tương thích 100% với SM8150** — địa chỉ thanh ghi, kích thước vùng nhớ và ngắt giống hệt |
| **CPU / SMP** | Đa nhân qua PSCI `CPU_ON`, trang nhớ 16K (`cpus=8`, bản vá `0065`, `0078`) | **Đã cập nhật trong `mkadt.py`:** 8 nhân Kryo 485 (`cpu@0..300` Silver A55, `cpu@400..600` Gold A76, `cpu@700` Gold Prime A76), sơ đồ MPIDR (`core << 8`) |
| **Lưu trữ UFS** | Trình điều khiển UFSHCI riêng (`bsd/dev/sweet_ufs.c`), mount HFS+ đọc/ghi từ `userdata` | **Tương thích 100% với SM8150:** `UFS_BASE = 0x01d84000`, kích thước `0x2500`, IRQ `GIC_SPI 265` (`0x109`) giống hệt |
| **Màn hình (`AppleCLCD`)** | IOSurface + IOMobileFramebuffer dựng hình CPU, hiển thị canvas iPhone X `1125×2436`, tắt/bật màn hình qua nút nguồn (`0079`) | **Đã cập nhật cho GM1901 (`1080×2340`, `36 MiB`):** trong `shim/console.h`, `tools/mkadt.py`, `sweet_early.c` và `SweetHID.cpp` (`0082`) |
| **Nguồn RPMh (`sweet_rpmh.c`)** | Điều khiển LDO qua RSC (`0x18220000`), TCS (`0x18220d00`), Cmd-DB (`0x0c3f000c`), DRV 2, ACTIVE TCS 2 (`0062`) | **Đã cập nhật trong `0082`:** bật nguồn cảm ứng **`"ldoa17"`** (`pm8150_l17`) ở mức áp **`3008` mV** |
| **Phím cứng (`sweet_keys.c`)** | Đọc trạng thái thời gian thực PMIC qua SPMI arbiter v5 (`0x0c440000` / `0x0e600000` / `0x0c40a000`) (`0060`) | **Đã cập nhật trong `0082`:** Power = SID 0 `pon@800` (`0x008` bit 0); **Vol+ = SID 0 GPIO6 (`0x0c5`, `0xc510` bit 0 active-low)**; **Vol- = SID 0 GPIO7 (`0x0c6`, `0xc610` bit 0 active-low) / `0x008` bit 1** |
| **Cảm ứng (`sweet_touch.c`)** | Khung GENI I²C + dịch vụ HID digitizer (`SweetHIDTouch`, hỗ trợ vuốt cạnh về Home ở `0071`) | **Đã cập nhật sang Synaptics S3706 trong `0082`:** bus `/soc/i2c@0xc80000` (`qupv3_se17_i2c`), địa chỉ **`0x20`**, clock GCC `0x52014` + `0x1e144`, TLMM `SOUTH` (`0x03d00000`) GPIO 54 (Reset), 55 (SDA), 56 (SCL), 119 (1.8V), 122 (IRQ), giao thức RMI4 Page 0 (`F01` / `F12`) |
| **USB & Mạng (`sweet_usb.c`)** | DWC3 device mode (`0074`), mạng USB CDC-ECM `ue0` (`192.168.7.2/24`, `0075`–`0076`), truyền log trực tiếp qua UDP cổng `5140` (`0077`) | **Đã cập nhật trong `0082`:** DWC3 `0x0a600000`, QSCRATCH `0x0a6f8800`, QUSB2 PHY `0x088e2000`, và các thanh ghi GCC `USB30_PRIM` của SM8150 (`cfg-noc-axi = 0x0f078`, `aggre-axi = 0x0f07c`, `clkref = 0x8c008`) |
| **Userland iOS 16.7.16** | Hệ thống tệp gốc và shared cache iPhone X (`iPhone10,3` / `D22AP`), Hactivation, SpringBoard, Cài đặt, điều hướng cử chỉ (`0070`–`0071`) | **Dùng chung hoàn toàn** image phân vùng gốc HFS+ (`ios16-root-20H392`) |

---

## Những gì chưa hoạt động (chung cho bản port)

- **Chưa có Wi-Fi, Bluetooth, mạng di động (baseband), âm thanh, camera, cảm biến, GPS, SEP / Face ID.** Các daemon tương ứng khởi động rồi gặp lỗi hoặc được vô hiệu hóa trong image gốc.
- **Chưa có trình điều khiển GPU Adreno.** CPU dựng toàn bộ hình ảnh qua CoreAnimation phần mềm ở khoảng 20–30 fps.
- **Mạng Internet cho ứng dụng iOS qua USB:** giao diện kernel `ue0` đã ping/nhận gói tin và truyền log UDP với máy tính (`192.168.7.2` <-> `192.168.7.1`), nhưng `configd` của iOS cần thêm đối tượng `IONetworkInterface` trong IOKit để cấp route/DNS cho ứng dụng.
- **Đã tắt bảo mật:** chính sách ký mã (AMFI) và sandbox được nới lỏng, AppleKeyStore chỉ là bản stub, không có bảo vệ dữ liệu. Không lưu dữ liệu cá nhân trên thiết bị.

---

## Quy trình khởi động

```
ABL (bootloader UEFI Qualcomm của OnePlus 7 GM1901, đã mở khóa)
  -> fastboot boot shim-boot.img              (tạm thời; không ghi đè phân vùng boot)
     -> shim: tự thiết lập MMU, đọc FDT hiện có, nạp payload từ ramdisk
        -> XNU Mach-O + Apple Device Tree (ADT) được tạo + boot-args
           -> XNU -> trình điều khiển UFS (0x01d84000) -> phân vùng gốc HFS+ trong userdata
              -> dyld + shared cache -> launchd -> daemon -> backboardd + SpringBoard
```

Kernel hiển thị console vào framebuffer mà ABL để lại tại `0x9c000000`, đồng thời lưu vòng log 4 MiB bền vững ở cuối `userdata` và phát luồng log UDP qua USB (`192.168.7.1:5140` khi bật `sweetusb=2`).

---

## Các tệp firmware GM1901 cục bộ trong máy của bạn

Các tệp ROM/firmware của OnePlus 7 (`GM1901`) đang có trong máy (đã được loại trừ khỏi git):

| Đường dẫn cục bộ | Mô tả |
| --- | --- |
| `default-img/OnePlus7Oxygen_14.O.11_OTA_011_all_1906072127_boot.img` | `boot.img` gốc của OxygenOS (`14.O.11`, header v1, chứa kernel Linux 4.14 + 4 base DTB `SM8150`) |
| `evolutionX-rom/boot.img`, `evolutionX-rom/dtbo.img` | `boot.img` (header v2, 20 DTB) và `dtbo.img` (10 overlay) của ROM Evolution X Android 16 cho GM1901 |
| `~/Downloads/OnePlus7Oxygen_14.O.22_OTA_022_all_1911070324_835275f5.zip` | Gói OTA OxygenOS `14.O.22` đầy đủ (chứa `boot.img`, `dtbo.img` với 39 overlay, `abl.img` UEFI `LinuxLoader.efi`, `xbl.img`, `aop.img`) |
| `research/gm1901/` | Thư mục chứa kernel đã giải nén & gắn relocation (`Image_reloc.bin`), ELF driver `s3706_driver_v2.elf` phục vụ phân tích MCP REA, cùng toàn bộ `dtb_00..03.dtb` và `dtbo_00..38.dtb` |

---

## Hướng dẫn sử dụng chi tiết cho OnePlus 7 (`GM1901`)

Bạn cần máy **OnePlus 7 (`GM1901`, SM8150)** đã **mở khóa bootloader**, máy tính **macOS** (có sẵn Xcode Command Line Tools + `python3`) hoặc **Linux**, cùng công cụ `fastboot`/`adb`.

---

### Bước 0. Sao lưu các phân vùng quan trọng của máy (Bắt buộc trước khi đụng vào `userdata`)

Trước khi flash bất kỳ thứ gì vào `userdata`, hãy khởi động tạm vào recovery có `adb` (TWRP / OrangeFox / Lineage Recovery) và sao lưu các phân vùng nhạy cảm chứa IMEI, hiệu chuẩn cảm biến/vân tay và bootloader:

```sh
mkdir -p backup
for part in persist modemst1 modemst2 fsg fsc boot_a boot_b dtbo_a dtbo_b vbmeta_a vbmeta_b; do
    adb shell "dd if=/dev/block/by-name/$part" > "backup/${part}.img"
done
```

> **Lưu ý:** Không bao giờ đưa thư mục `backup/` vào git (`.gitignore` đã tự động chặn).

---

### Bước 1. Build và chạy thử Boot Shim chẩn đoán (An toàn 100% — Không ghi vào ổ cứng)

Khi chạy [`./shim/build.sh`](file:///Users/nguyendinhkhanh/Documents/GitHub/ios-sweet/shim/build.sh) **không truyền tham số**, script sẽ tạo một boot image chẩn đoán (không kèm XNU). Khi `fastboot boot` ảnh này, máy sẽ:
1. Xóa màn hình `1080×2340` sang nền đỏ chữ vàng/trắng.
2. Đọc thử bảng phân vùng GPT trên chip nhớ UFS (`0x01d84000`) ở chế độ **chỉ đọc (read-only)** và in danh sách các phân vùng lớn (`userdata`, v.v.) lên màn hình điện thoại.
3. Giữ kết quả trên màn hình ~3 phút rồi tự động khởi động lại về `fastboot` (nhờ ghi `0x77665500` vào `IMEM_RESTART_REASON = 0x146bf65c`).

Chạy lệnh sau trên máy Mac của bạn:

```sh
./shim/build.sh
```

Script sẽ tự động biên dịch mã nguồn trong [`shim/`](file:///Users/nguyendinhkhanh/Documents/GitHub/ios-sweet/shim), kiểm tra layout màn hình qua `shim/out/host_test` (xuất ảnh mẫu `shim/out/host.ppm` kích thước `1080×2340`), trích xuất DTB từ thư mục `default-img/` và `evolutionX-rom/`, rồi sinh ra **2 file boot image**:

| File đầu ra | Định dạng đóng gói | Khi nào sử dụng? |
| --- | --- | --- |
| `shim/out/shim-boot.img` | Android Boot Header **v2** (`dtb_offset = 0x1f00000`, lấy DTB từ `evolutionX-rom/boot.img`) | Dùng khi máy bạn đang chạy **Evolution X** hoặc firmware **OxygenOS 11 / 12** |
| `shim/out/shim-boot-oos.img` | Android Boot Header **v1** + tiền tố 20 byte `UNCOMPRESSED_IMG` + DTB nối đuôi (lấy từ `default-img/OnePlus7Oxygen_14.O.11...`) | Dùng khi máy bạn đang ở bootloader **OxygenOS 9 / 10** gốc (`14.O.11` / `14.O.22`) |

Để khởi động thử nghiệm (tạm thời trên RAM, không làm mất Android):
```sh
# Đưa OnePlus 7 về chế độ Fastboot (nhấn giữ Nguồn + Tăng âm lượng hoặc adb reboot bootloader)
fastboot boot shim/out/shim-boot.img
# Nếu bootloader báo lỗi DTB trên nền OxygenOS 9/10 cũ, dùng file OOS:
fastboot boot shim/out/shim-boot-oos.img
```

---

### Bước 2. Tạo Apple Device Tree (`gm1901.adt`) cho OnePlus 7

`MobileGestalt` của iOS 16 cần node `/product` từ DeviceTree gốc của iPhone X (`d22ap.adt`) để nhận diện đúng thiết bị Face ID không có nút Home.

1. **Trích xuất `d22ap.adt` từ IPSW iPhone X (`20H392`) — chỉ cần làm 1 lần:**
   ```sh
   python3 tools/remotezip.py IPSW_URL DeviceTree.d22ap.im4p research/ipsw-x/dt
   ipsw img4 im4p extract research/ipsw-x/dt/Firmware/all_flash/DeviceTree.d22ap.im4p -o research/ipsw-x/d22ap.adt
   ```
2. **Tạo file `shim/out/gm1901.adt` bằng [`tools/mkadt.py`](file:///Users/nguyendinhkhanh/Documents/GitHub/ios-sweet/tools/mkadt.py):**
   ```sh
   # Dùng bank RAM trên (0x1_00000000, ~3.95 GiB):
   python3 tools/mkadt.py shim/out/gm1901.adt --highmem

   # Hoặc dùng bank RAM dưới (0xb0000000, ~1.2 GiB) nếu muốn kiểm tra an toàn bước đầu:
   python3 tools/mkadt.py shim/out/gm1901-low.adt

   # Xem toàn bộ cây thiết bị đã tạo:
   python3 tools/mkadt.py shim/out/gm1901.adt --highmem --dump
   ```

---

### Bước 3. Build Kernel XNU

Kernel XNU (`xnu-8796`) được build tự động trên runner macOS của GitHub Actions qua workflow [`.github/workflows/xnu.yml`](file:///Users/nguyendinhkhanh/Documents/GitHub/ios-sweet/.github/workflows/xnu.yml):

```sh
# 1. Kiểm tra các bản vá trong xnu/patches/ áp dụng sạch trước khi push:
python3 research/check-patch-order.py

# 2. Kích hoạt build trên GitHub Actions và tải kernel về:
gh workflow run xnu.yml -R YOU/ios-sweet
gh run watch -R YOU/ios-sweet
gh run download RUN_ID -R YOU/ios-sweet -n xnu-kernel -D xnu/out
```

---

### Bước 4. Đóng gói Payload XNU vào `boot.img` của GM1901

Sau khi có kernel XNU (`xnu/out/kernel.development.sweet`) và file ADT (`shim/out/gm1901.adt`):

1. **Tạo payload bằng [`tools/mkpayload.py`](file:///Users/nguyendinhkhanh/Documents/GitHub/ios-sweet/tools/mkpayload.py):**
   ```sh
   # Cấu hình khuyên dùng khi bring-up lần đầu trên GM1901 (hiện chữ console trên màn hình, bật USB live log):
   python3 tools/mkpayload.py \
       xnu/out/kernel.development.sweet \
       shim/out/gm1901.adt \
       shim/out/payload-gm1901.bin \
       --cmdline 'debug=0xc serial=3 cpus=8 keepsyms=1 -enable_kprintf_spam -noprogress rd=ufsroot0 unentitled_ios_sim_launch=1 ignition_level=1 wdt_test=no_user_checkin ufsrw=1 rootrw=1 launchd_unsecure_cache=1 wdt=-1 sweetfb_hz=30 sweetusb=2'
   ```
2. **Đóng gói payload vào `shim-boot.img` và `shim-boot-oos.img` bằng [`shim/build.sh`](file:///Users/nguyendinhkhanh/Documents/GitHub/ios-sweet/shim/build.sh):**
   ```sh
   ./shim/build.sh shim/out/payload-gm1901.bin
   ```
3. **Kiểm tra lại tính toàn vẹn của `shim-boot.img`:**
   ```sh
   python3 tools/unpack_bootv2.py shim/out/shim-boot.img shim/out/check
   cmp shim/out/check/ramdisk shim/out/payload-gm1901.bin && echo "OK!"
   rm -rf shim/out/check
   ```

#### Bảng tra cứu các cờ `boot-args` quan trọng

| Boot-arg | Tác dụng |
| --- | --- |
| `rd=ufsroot0 ufsrw=1 rootrw=1` | Mount phân vùng `userdata` trên UFS làm phân vùng gốc HFS+ ở chế độ đọc/ghi |
| `cpus=8` | Khởi động đủ 8 lõi Kryo 485 qua PSCI (`cpus=1` hoặc `cpus=4` nếu muốn chỉ chạy cụm lõi tiết kiệm điện A55 khi debug) |
| `sweetfb_noconsole=1` | Ẩn chữ log của kernel trên màn hình để chỉ hiển thị giao diện iOS (bỏ cờ này trong lần boot đầu để nhìn thấy log trực tiếp trên màn hình) |
| `sweetfb_hz=30` | Giới hạn tần số chép framebuffer ở 30 Hz để giảm tải cho CPU |
| `sweetusb=2` | Bật mạng USB CDC-ECM (`192.168.7.2/24`) và tự động bắn luồng log console qua UDP tới `192.168.7.1:5140` mỗi 100 ms |
| `sweettouch=0`, `sweetkeys=0` | Tắt tạm thời trình điều khiển cảm ứng hoặc phím bấm nếu cần cô lập lỗi phần cứng |
| `wdt=-1 wdt_test=no_user_checkin` | Vô hiệu hóa watchdog phần cứng và watchdog không gian người dùng |
| `launchd_unsecure_cache=1` | Cho phép `launchd` nạp cache dịch vụ mà không đòi hỏi xác thực chữ ký AMFI |

---

### Bước 5. Tạo & Flash phân vùng gốc iOS (`userdata`) và Khởi động

1. **Tạo image HFS+ từ IPSW iPhone X (`20H392`) (trên máy Linux có `apfs-fuse` và `hfsprogs`):**
   ```sh
   tools/mkiosroot.sh OS.dmg SystemOS.dmg AppOS.dmg ios16-root.img 16G
   sudo fsck.hfsplus -fy ios16-root.img
   sudo mount -t hfsplus -o loop,force ios16-root.img /mnt/iosroot
   sudo python3 tools/sweet-root-tweaks.py /mnt/iosroot
   sudo umount /mnt/iosroot
   img2simg ios16-root.img ios16-root.simg
   ```
2. **Flash vào phân vùng `userdata` (CẢNH BÁO: Xóa sạch dữ liệu Android trong `userdata`):**
   ```sh
   fastboot -S 512M flash userdata ios16-root.simg
   ```
3. **Khởi động iOS tạm thời qua `fastboot boot`:**
   ```sh
   # Với máy chạy bootloader Evolution X / OOS 11-12:
   fastboot boot shim/out/shim-boot.img

   # Hoặc với máy chạy bootloader OOS 9/10 gốc:
   fastboot boot shim/out/shim-boot-oos.img
   ```

---

### Bước 6. Thu thập Log & Gỡ lỗi

- **Cách 1 — Xem log trực tiếp theo thời gian thực qua cáp USB (`sweetusb=2`):**
  Khi kernel đã khởi tạo xong DWC3 USB CDC-ECM, máy tính sẽ nhận một card mạng USB Ethernet (`1209:0001`). Chạy:
  ```sh
  tools/sweet-usbnet.sh logs/live-gm1901.txt
  ```
  Script sẽ đặt IP máy tính là `192.168.7.1/24` và hứng toàn bộ log UDP tại cổng `5140` (bao gồm cả 64 KiB lịch sử đầu khởi động). Có thể kiểm tra kết nối bằng `ping 192.168.7.2`.
- **Cách 2 — Đọc vòng log 4 MiB lưu bền vững ở cuối phân vùng `userdata` (khi máy treo/panic sớm):**
  ```sh
  fastboot boot recovery/recovery.img
  tools/sweet-log-pull.sh logs/boot-gm1901.txt
  adb reboot bootloader
  ```
- **Giải mã địa chỉ hàm khi crash (`CRASH name ...`):**
  ```sh
  python3 tools/sweet-crash.py logs/boot-gm1901.txt
  ```

---

## Cấu trúc repository

| Đường dẫn | Nội dung |
| --- | --- |
| [`shim/`](file:///Users/nguyendinhkhanh/Documents/GitHub/ios-sweet/shim) | Boot shim bare-metal (C + asm), đóng gói thành Android `boot.img` |
| [`xnu/patches/`](file:///Users/nguyendinhkhanh/Documents/GitHub/ios-sweet/xnu/patches) | Chuỗi bản vá XNU (`0001`–`0082`), cùng script chuẩn bị `libpthread`, `HFS` và `BearSSL` |
| [`.github/workflows/xnu.yml`](file:///Users/nguyendinhkhanh/Documents/GitHub/ios-sweet/.github/workflows/xnu.yml) | GitHub Actions workflow build kernel XNU trên runner macOS |
| [`tools/mkadt.py`](file:///Users/nguyendinhkhanh/Documents/GitHub/ios-sweet/tools/mkadt.py) | Tạo Apple Device Tree (ADT) từ bố trí MMIO và danh tính iPhone X |
| [`tools/mkpayload.py`](file:///Users/nguyendinhkhanh/Documents/GitHub/ios-sweet/tools/mkpayload.py) | Đóng gói kernel + ADT + boot-args thành payload cho shim |
| [`tools/mkiosroot.sh`](file:///Users/nguyendinhkhanh/Documents/GitHub/ios-sweet/tools/mkiosroot.sh) | Tạo phân vùng gốc iOS HFS+ từ các image trong IPSW |
| [`tools/sweet-root-tweaks.py`](file:///Users/nguyendinhkhanh/Documents/GitHub/ios-sweet/tools/sweet-root-tweaks.py) | Điều chỉnh phân vùng gốc cho bring-up (bỏ qua Setup, kích hoạt, daemon) |
| [`tools/sweet-usbnet.sh`](file:///Users/nguyendinhkhanh/Documents/GitHub/ios-sweet/tools/sweet-usbnet.sh) | Thiết lập mạng USB CDC-ECM trên máy tính và nhận luồng log UDP trực tiếp |
| [`tools/sweet-log-pull.sh`](file:///Users/nguyendinhkhanh/Documents/GitHub/ios-sweet/tools/sweet-log-pull.sh), [`tools/sweet-log.py`](file:///Users/nguyendinhkhanh/Documents/GitHub/ios-sweet/tools/sweet-log.py) | Đọc log kernel bền vững từ cuối `userdata` qua recovery |
| [`tools/sweet-crash.py`](file:///Users/nguyendinhkhanh/Documents/GitHub/ios-sweet/tools/sweet-crash.py) | Symbolicate báo cáo crash của console |
| [`tools/xnu-cc.py`](file:///Users/nguyendinhkhanh/Documents/GitHub/ios-sweet/tools/xnu-cc.py) | Kiểm tra biên dịch một tệp cục bộ dựa trên log CI |
| [`tools/qemu-sweet.py`](file:///Users/nguyendinhkhanh/Documents/GitHub/ios-sweet/tools/qemu-sweet.py) | Khởi động thử trên QEMU `virt`, giải mã văn bản framebuffer |
| [`NOTES.md`](file:///Users/nguyendinhkhanh/Documents/GitHub/ios-sweet/NOTES.md) | Nhật ký kỹ thuật chi tiết: kết quả dịch ngược GM1901 bằng MCP REA, thông số thanh ghi và lịch sử các bản vá |

---

## Các bản vá kernel (`0001`–`0082`)

| # | Nội dung |
| --- | --- |
| 0001–0009 | Tương thích toolchain, cấu hình máy `SWEET`, arm64 không PAC, stub cho các thành phần nội bộ của Apple |
| 0010–0018 | Console framebuffer giai đoạn sớm, sửa physmap, PRNG không cần corecrypto, device-tree platform expert, timer PPI, trình điều khiển CPU khởi động |
| 0019–0020 | Provider `libpthread` kernel mã nguồn mở của Apple; AES của BearSSL |
| 0021–0027 | Phân vùng gốc RAM-disk, `mockfs`, SHA-256, AMFI tối thiểu, HFS+ mã nguồn mở của Apple, MD5 |
| 0028–0034 | Trình điều khiển UFS host và thiết bị gốc, phân vùng gốc đọc/ghi, DMA trên 4 GiB |
| 0035–0045 | Entitlement, `bindfs`, `AppleKeyStore` stub, `IOWatchdog`, báo cáo crash của console |
| 0046 | Các dịch vụ `IOSurface` (`IOCoreSurfaceRoot`) và `IOMobileFramebuffer` (`AppleCLCD`) |
| 0047–0055 | Chẩn đoán: log bền vững, tee `/dev/null`, trace IOKit, chuỗi heap và lấy mẫu user stack khi crash; chính sách Sandbox nới lỏng; HFS rename-swap; `AppleKeyStore` selector |
| 0056–0057 | Giới hạn tốc độ chép khung hình lên màn hình; không dùng bộ phân giải danh tính bên ngoài |
| 0058 | Dịch vụ sự kiện HID: user client và hàng đợi sự kiện `IOHIDFamily-1915.140.3` của Apple |
| 0059 | Danh tính iPhone X (`hw.product` / `hw.target` lấy từ device tree) |
| 0060 | Nút nguồn và âm lượng qua SPMI (`sweet_keys.c`); cảm ứng qua GENI I²C (`sweet_touch.c`) |
| 0061 | Hiển thị độ phân giải màn hình là `1125×2436` (chuẩn iPhone X) |
| 0062 | Yêu cầu regulator RPMh (`sweet_rpmh.c`) để cấp nguồn cho cảm ứng; nguồn pin `IOPMPowerSource` |
| 0063 | Sửa đóng gói FIFO GENI I²C |
| 0064 | Cấp quyền `PRIV_WORK_INTERVAL` (khoảng làm việc CoreAnimation của UIKit) |
| 0065 | SMP: khởi động các lõi phụ qua PSCI `CPU_ON` |
| 0066–0069 | Thông tin vùng lỗi khi crash; tắt chữ console; tra cứu `IOSurface` đã ánh xạ; ghi log bền vững theo lô |
| 0070–0071 | Bật syscall `pid_hibernate` (435) và cờ cạnh `kIOHIDDigitizerEventFromEdgeTip` giúp vuốt từ cạnh dưới về màn hình chính & mở đa nhiệm hoạt động |
| 0072–0077 | Trình điều khiển USB DWC3 device mode (`sweet_usb.c`), ép VBUS qua QSCRATCH, giao diện mạng CDC-ECM `ue0` (`192.168.7.2/24`) và truyền log trực tiếp qua UDP |
| 0078–0081 | Khởi động đủ 8 lõi CPU (`cpus=8`), tắt/bật màn hình qua nút nguồn (`kern_RequestPowerChange`), theo dõi bảng định tuyến mạng và trạng thái liên kết USB |
| 0082 | **Cổng chuyển các trình điều khiển sang OnePlus 7 (`GM1901` / SM8150):** màn hình `1080×2340` (`sweet_early.c`, `SweetHID.cpp`), nút cứng PM8150 SID 0 GPIO6/GPIO7 (`sweet_keys.c`), nguồn RPMh `"ldoa17"` `3008` mV (`sweet_rpmh.c`), cảm ứng Synaptics S3706 RMI4 trên GENI SE17 I²C `0x00c80000` (`sweet_touch.c`), và các thanh ghi CBCR clock USB của SM8150 (`sweet_usb.c`) |

---

## Thông tin phần cứng chính — OnePlus 7 (`GM1901`, SM8150)

- **SoC & Board:** Qualcomm Snapdragon 855 (`SM8150 v2`, `msm-id = <0x153 0x20000>`), mã dự án OnePlus `oem,project-id = <0x49a9>` (`18857`, `guacamoleb`).
- **CPU:** 8 lõi Kryo 485 (`cpu@0..300` Silver A55, `cpu@400..600` Gold A76, `cpu@700` Gold Prime A76), PSCI qua `smc`, MPIDR `reg = core << 8`, timer `19.2 MHz` (GICv3 PPI 19).
- **Khởi động lại / Cấp nguồn:** `PSHOLD = 0x0c264000`, `IMEM restart_reason = 0x146bf65c` (`imem@146bf000 + 0x65c`).
- **Màn hình:** AMOLED Samsung `s6e3fc2x01_cmd` / `sofef03f_m`, độ phân giải vật lý **`1080×2340`** (stride `4320`), vùng framebuffer `cont_splash_region` của ABL tại `0x9c000000` (kích thước `0x02400000` = `36 MiB`).
- **Lưu trữ UFS:** UFSHCI tại `0x01d84000` (`0x2500`), IRQ `GIC_SPI 265` (`0x109`).
- **Cảm ứng (`synaptics-s3706`):**
  - Bus GENI I²C `/soc/i2c@0xc80000` (`qupv3_se17_i2c`, SE đầu tiên trong Wrapper 2 `qcom,qupv3_2_geni_se@cc0000`), địa chỉ slave **`0x20`**.
  - Nguồn: 1.8V qua TLMM **GPIO 119** (`tp_1v8`) + 2.8V/3.0V qua RPMh LDO **`"ldoa17"`** (`pm8150_l17`, `3008` mV).
  - Chân TLMM (đều thuộc tile `SOUTH = 0x03d00000`, stride `0x1000`): **GPIO 55** (SDA, `mux = 1`), **GPIO 56** (SCL, `mux = 1`), **GPIO 54** (Reset, active-low), **GPIO 119** (1.8V enable), **GPIO 122** (IRQ).
  - Clock GCC (`0x00100000`): `gcc_qupv3_wrap2_s0_clk` (`CBCR = 0x1e144`, `CMD_RCGR = 0x1e148`), `m_ahb` (`0x1e004`), `s_ahb` (`0x1e008`), vote qua `APCS_CLOCK_BRANCH_ENA_VOTE_1` (`0x52014`).
  - Giao thức RMI4 Page `0x00`: PDT `F01` tại `0xe3` (`data_base = 0x04`), `F12` (2D touch) tại `0xdd` (`data_base = 0x08`, 8 byte/ngón, tọa độ 12-bit `0..1079` × `0..2339`).
- **Nút bấm & Alert Slider:**
  - SPMI arbiter v5 (`0x0c440000` core, `0x0e600000` observer, `0x0c40a000` cnfg).
  - Nút nguồn (`kpdpwr`): PM8150 SID 0 `pon@800` (PPID `0x008`, `0x0810` bit 0).
  - Tăng âm lượng (`vol_up`): PM8150 SID 0 GPIO6 (PPID `0x0c5`, `0xc510` bit 0, active-low).
  - Giảm âm lượng (`vol_down`): PM8150 SID 0 GPIO7 (PPID `0x0c6`, `0xc610` bit 0, active-low) và/hoặc `pon@800` `resin` (`0x0810` bit 1).
  - Cần gạt 3 nấc (`tri_state_key`): TLMM GPIO 27 (`EAST` `0x0351b000`), GPIO 125 (`WEST` `0x0317d000`), GPIO 134 (`SOUTH` `0x03d86000`).
- **USB:** DWC3 tại `0x0a600000`, QSCRATCH tại `0x0a6f8800`, QUSB2 PHY tại `0x088e2000`, GCC `USB30_PRIM` tại `0x0f004..0x0f018`.

Xem chi tiết quá trình phân tích trong [`NOTES.md`](file:///Users/nguyendinhkhanh/Documents/GitHub/ios-sweet/NOTES.md).

## Ghi nhận

Dự án được xây dựng dựa trên các bản phát hành mã nguồn mở của Apple (`xnu`, `IOHIDFamily`, `libpthread`, `hfs`), [BearSSL](https://bearssl.org), [blacktop/darwin-xnu-build](https://github.com/blacktop/darwin-xnu-build), [ipsw](https://github.com/blacktop/ipsw), mã nguồn Linux kernel và DTB/DTBO của Qualcomm/OnePlus để tra cứu thông tin phần cứng. Bản thân iOS thuộc sở hữu của Apple và không được phân phối trong dự án này.
