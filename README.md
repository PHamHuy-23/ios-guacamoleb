# ios-sweet (Nhánh port cho OnePlus 7 — GM1901)

**Dự án port iOS 16 (XNU 8796 + userland iPhone X 16.7.16 `20H392`) sang OnePlus 7 (`GM1901` / `guacamoleb`, Qualcomm Snapdragon 855 / SM8150).**

Repository này xuất phát từ bản bring-up iOS 16.7.16 trên nền Qualcomm Snapdragon (`sweet` / SM7150 — đã khởi động lên màn hình chính iOS, cảm ứng, phím cứng, 8 nhân SMP và mạng USB CDC-ECM qua bản vá `0080`), và hiện được chuyển hướng sang thiết bị mục tiêu của máy bạn: **OnePlus 7 (`GM1901`, SM8150, bootloader đã mở khóa)**.

> **Tình trạng hiện tại (2026-10-21):**
> - **Đã hoàn tất giải nén firmware & dịch ngược driver của máy GM1901** từ ROM gốc OxygenOS (`OnePlus7Oxygen_14.O.11` / `14.O.22`) và Evolution X (`Android 16`), sử dụng công cụ tách DTB/DTBO (`dtb_02.dtb`, `dtbo_20.dtb` cho `project-id = 0x49a9` / `18857`), UEFI `LinuxLoader.efi` (`abl.img`) và **MCP REA** trên kernel `Image` của GM1901.
> - **Chưa nạp/boot thử trên phần cứng OnePlus 7 thật:** mã nguồn trong `shim/`, `tools/mkadt.py` và `xnu/patches/` hiện vẫn đang giữ các hằng số mặc định của nền `sweet` (SM7150) và đang ở bước chuẩn bị áp bản vá phần cứng GM1901 (SM8150) theo bảng ánh xạ đã xác minh bên dưới.
> - Đây là bản bring-up thử nghiệm. Khi cài đặt rootfs iOS vào phân vùng `userdata`, **toàn bộ dữ liệu người dùng Android sẽ bị xóa** (các phân vùng bootloader, recovery, modem, persist được giữ nguyên).

---

## Trạng thái các thành phần đối với OnePlus 7 (`GM1901` — SM8150)

| Hạng mục | Trạng thái trên nền tảng XNU hiện có | Tình trạng tương thích / Cổng chuyển sang OnePlus 7 (`GM1901`) |
| --- | --- | --- |
| **Khởi động (`shim/`)** | Bootloader Qualcomm ABL → `fastboot boot` shim → XNU Mach-O + ADT | **Đã xác minh định dạng:** ROM OxygenOS gốc dùng `boot.img` header v1 (kernel kèm header 20 byte `UNCOMPRESSED_IMG` + `dtb_02.dtb` nối đuôi); ROM Evolution X dùng `boot.img` header v2 (`--dtb_offset 0x1f00000`). Cần đổi địa chỉ `IMEM_RESTART` trong `shim/shim.c` sang `0x146bf65c` |
| **GICv3 & Timer** | GICv3 (`GICD = 0x17a00000`, `GICR = 0x17a60000`, stride `0x20000`), timer 19,2 MHz (PPI 19) | **Tương thích 100% với SM8150** — địa chỉ thanh ghi, kích thước vùng nhớ và ngắt giống hệt |
| **CPU / SMP** | Đa nhân qua PSCI `CPU_ON`, trang nhớ 16K (`cpus=8`, bản vá `0065`, `0078`) | **Tương thích sơ đồ MPIDR (`core << 8`):** GM1901 có 8 nhân Kryo 485 (`cpu@0..300` Silver A55, `cpu@400..600` Gold A76, `cpu@700` Gold Prime A76) |
| **Lưu trữ UFS** | Trình điều khiển UFSHCI riêng (`bsd/dev/sweet_ufs.c`), mount HFS+ đọc/ghi từ `userdata` | **Tương thích 100% với SM8150:** `UFS_BASE = 0x01d84000`, kích thước `0x2500`, IRQ `GIC_SPI 265` (`0x109`) giống hệt |
| **Màn hình (`AppleCLCD`)** | IOSurface + IOMobileFramebuffer dựng hình CPU, hiển thị canvas iPhone X `1125×2436`, tắt/bật màn hình qua nút nguồn (`0079`) | **Cần cập nhật chiều cao panel:** GM1901 dùng vùng splash `0x9c000000` (`36 MiB`), panel Samsung `s6e3fc2x01_cmd` / `sofef03f_m` độ phân giải vật lý **`1080×2340`** (stride `4320`), thay cho `1080×2400` |
| **Nguồn RPMh (`sweet_rpmh.c`)** | Điều khiển LDO qua RSC (`0x18220000`), TCS (`0x18220d00`), Cmd-DB (`0x0c3f000c`), DRV 2, ACTIVE TCS 2 (`0062`) | **Thanh ghi RPMh & Cmd-DB giống 100%:** trên GM1901 chỉ cần đổi tên nguồn cảm ứng sang **`"ldoa17"`** (`pm8150_l17`) ở mức áp **`3008` mV** |
| **Phím cứng (`sweet_keys.c`)** | Đọc trạng thái thời gian thực PMIC qua SPMI arbiter v5 (`0x0c440000` / `0x0e600000` / `0x0c40a000`) (`0060`) | **SPMI giống 100%, cần đổi PPID nút âm lượng:** Power = SID 0 `pon@800` (`0x008` bit 0); **Vol+ = SID 0 GPIO6 (`0x0c5`, `0xc510` bit 0 active-low)**; **Vol- = SID 0 GPIO7 (`0x0c6`, `0xc610` bit 0 active-low) / `0x008` bit 1**. Cần gạt Alert Slider nối vào TLMM GPIO 27 / 125 / 134 |
| **Cảm ứng (`sweet_touch.c`)** | Khung GENI I²C + dịch vụ HID digitizer (`SweetHIDTouch`, hỗ trợ vuốt cạnh về Home ở `0071`) | **Đã dịch ngược xong bằng MCP REA, cần thay giao thức sang Synaptics S3706:** bus `/soc/i2c@0xc80000` (`qupv3_se17_i2c`), địa chỉ **`0x20`**, clock GCC `0x52014` + `0x1e144`, TLMM `SOUTH` (`0x03d00000`) GPIO 54 (Reset), 55 (SDA), 56 (SCL), 119 (1.8V), 122 (IRQ), giao thức RMI4 Page 0 (`F01` / `F12`) |
| **USB & Mạng (`sweet_usb.c`)** | DWC3 device mode (`0074`), mạng USB CDC-ECM `ue0` (`192.168.7.2/24`, `0075`–`0076`), truyền log trực tiếp qua UDP cổng `5140` (`0077`) | **Tương thích 100% với SM8150:** DWC3 core `0x0a600000`, QSCRATCH `0x0a6f8800`, QUSB2 PHY `0x088e2000` và các thanh ghi GCC `USB30_PRIM` (`0x0f004..0x0f018`) giống hệt |
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

## Hướng dẫn chuẩn bị & thực hiện

Bạn cần máy **OnePlus 7 (`GM1901`, SM8150)** đã **mở khóa bootloader**, máy tính (macOS/Linux) và tài khoản GitHub để build kernel. **Toàn bộ dữ liệu trong `userdata` sẽ bị xóa khi flash rootfs iOS.** Các phân vùng bootloader, recovery, modem và persist không bị động đến.

### 0. Sao lưu điện thoại

Trước khi can thiệp vào `userdata`, hãy khởi động tạm thời vào recovery có hỗ trợ `adb` (TWRP / OrangeFox / Lineage Recovery cho `guacamoleb`) và sao lưu ít nhất các phân vùng `persist`, `modemst1`, `modemst2`, `fsg`, `fsc`, `boot_a`/`boot_b`, `dtbo_a`/`dtbo_b`, `vbmeta_a`/`vbmeta_b`. Không đưa các bản sao lưu này vào git (`.gitignore` đã loại trừ `backup/`, `dtb/`, `recovery/`, `research/`, `default-img/`, `evolutionX-rom/`).

### 1. Build kernel XNU

Kernel được build trên runner macOS của GitHub bằng [blacktop/darwin-xnu-build](https://github.com/blacktop/darwin-xnu-build). Workflow tải `xnu-8796`, lần lượt áp dụng các bản vá trong [`xnu/patches/`](file:///Users/nguyendinhkhanh/Documents/GitHub/ios-sweet/xnu/patches), đồng thời chuẩn bị mã nguồn `libpthread`, `HFS` và `BearSSL` mã nguồn mở đã được ghim phiên bản:

```sh
gh workflow run xnu.yml -R YOU/ios-sweet
gh run download RUN_ID -R YOU/ios-sweet -n xnu-kernel -D xnu/out
```

Để kiểm tra nhanh một tệp C/C++ cục bộ trước khi chạy CI, dùng [`tools/xnu-cc.py`](file:///Users/nguyendinhkhanh/Documents/GitHub/ios-sweet/tools/xnu-cc.py) và [`research/check-patch-order.py`](file:///Users/nguyendinhkhanh/Documents/GitHub/ios-sweet/research/check-patch-order.py).

### 2. Tạo image phân vùng gốc iOS

Tải IPSW iOS 16.7.16 (`20H392`) của iPhone X (`iPhone10,3`) từ Apple. Sau đó dùng `apfs-fuse`, `hfsprogs` và `sudo` (trên Linux) để tạo volume HFS+:

```sh
# Các disk image OS, SystemOS và AppOS trong IPSW (xem tên trong BuildManifest.plist)
tools/mkiosroot.sh OS.dmg SystemOS.dmg AppOS.dmg ios16-root.img 16G
sudo fsck.hfsplus -fy ios16-root.img
sudo mount -t hfsplus -o loop,force ios16-root.img /mnt/iosroot
sudo python3 tools/sweet-root-tweaks.py /mnt/iosroot
sudo umount /mnt/iosroot
img2simg ios16-root.img ios16-root.simg
```

Công cụ tạo device tree chép `/product` từ device tree iPhone X thật (`d22ap.adt`), chỉ cần trích xuất một lần:

```sh
python3 tools/remotezip.py IPSW_URL DeviceTree.d22ap.im4p research/ipsw-x/dt
ipsw img4 im4p extract research/ipsw-x/dt/Firmware/all_flash/DeviceTree.d22ap.im4p -o research/ipsw-x/d22ap.adt
```

### 3. Tạo boot image

Sau khi áp các bản vá phần cứng GM1901 cho `shim/`, `tools/mkadt.py` và `xnu/patches/`:

```sh
python3 tools/mkadt.py shim/out/sweet.adt --highmem --cpus 8
python3 tools/mkpayload.py xnu/out/kernel.development.sweet shim/out/sweet.adt shim/out/payload.bin \
    --cmdline 'debug=0xc serial=3 cpus=8 keepsyms=1 -enable_kprintf_spam -noprogress rd=ufsroot0 unentitled_ios_sim_launch=1 ignition_level=1 wdt_test=no_user_checkin ufsrw=1 rootrw=1 launchd_unsecure_cache=1 wdt=-1 sweetfb_noconsole=1 sweetfb_hz=30 sweetusb=2'
shim/build.sh ../shim/out/payload.bin      # -> shim/out/shim-boot.img
```

Ý nghĩa của các boot-args chính:

| Boot-arg | Tác dụng |
| --- | --- |
| `rd=ufsroot0 ufsrw=1 rootrw=1` | Dùng phân vùng `userdata` làm phân vùng gốc HFS+, cho phép đọc/ghi |
| `cpus=8` | Khởi động cả 8 lõi CPU qua PSCI (`cpus=1` là phương án dự phòng an toàn khi debug bước đầu) |
| `launchd_unsecure_cache=1` | Cho phép `launchd` chấp nhận job cache mà không cần AMFI |
| `wdt=-1 wdt_test=no_user_checkin` | Tắt hardware watchdog |
| `sweetfb_noconsole=1` | Ẩn chữ console kernel đè lên giao diện iOS (khi cần xem chữ log trực tiếp trên màn hình trong lúc bring-up GM1901 lần đầu, hãy **bỏ** cờ này) |
| `sweetfb_hz=30` | Tần số cập nhật màn hình khi chép khung hình bằng CPU |
| `sweetusb=2` | Bật trình điều khiển USB DWC3 CDC-ECM (`192.168.7.2/24`) và truyền log kernel trực tiếp qua UDP `192.168.7.1:5140` |
| `sweettouch=0`, `sweetkeys=0` | Tắt trình điều khiển cảm ứng hoặc nút bấm nếu cần cô lập lỗi |

### 4. Ghi phân vùng gốc và khởi động tạm thời

```sh
fastboot -S 512M flash userdata ios16-root.simg
fastboot boot shim/out/shim-boot.img
```

### 5. Đọc log kernel (qua USB trực tiếp hoặc qua Recovery)

- **Cách 1 — Xem log trực tiếp qua cáp USB (khi `sweetusb=2` đã lên):**
  ```sh
  tools/sweet-usbnet.sh logs/live-boot.txt
  ```
- **Cách 2 — Đọc vòng log 4 MiB cuối `userdata` từ Recovery (khi máy panic/treo sớm trước khi USB lên):**
  ```sh
  fastboot boot recovery/recovery.img
  tools/sweet-log-pull.sh logs/boot.txt
  adb reboot bootloader
  ```

---

## Cấu trúc repository

| Đường dẫn | Nội dung |
| --- | --- |
| [`shim/`](file:///Users/nguyendinhkhanh/Documents/GitHub/ios-sweet/shim) | Boot shim bare-metal (C + asm), đóng gói thành Android `boot.img` |
| [`xnu/patches/`](file:///Users/nguyendinhkhanh/Documents/GitHub/ios-sweet/xnu/patches) | Chuỗi bản vá XNU (`0001`–`0080`), cùng script chuẩn bị `libpthread`, `HFS` và `BearSSL` |
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

## Các bản vá kernel (`0001`–`0080`)

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
| 0078–0080 | Khởi động đủ 8 lõi CPU (`cpus=8`), tắt/bật màn hình qua nút nguồn (`kern_RequestPowerChange`) và theo dõi bảng định tuyến mạng |

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
