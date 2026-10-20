# ios-sweet

**iOS 16 của Apple chạy trên Redmi Note 10 Pro.**

Dự án này port kernel XNU mã nguồn mở của Apple (xnu-8796, thế hệ iOS 16) sang Xiaomi Redmi Note 10 Pro (`sweet`, Qualcomm SM7150 / Snapdragon 732G). Trên đó chạy **userland iOS 16.7.16 (20H392) nguyên bản của iPhone X**: launchd, các daemon hệ thống, backboardd, SpringBoard và các ứng dụng có sẵn.

Tính đến **2026-10-18**, điện thoại khởi động được đến **màn hình chính iOS**. Bạn có thể mở khóa, vào Cài đặt, vuốt xuống để mở Trung tâm điều khiển và Trung tâm thông báo, đồng thời dùng màn hình cảm ứng và các nút phần cứng. Toàn bộ quá trình dựng hình chạy trên CPU; hiện chưa có trình điều khiển GPU.

> Đây là bản bring-up thử nghiệm, chưa phải hệ điều hành điện thoại có thể sử dụng hằng ngày. Nhiều tính năng còn thiếu hoặc chỉ được mô phỏng (xem bên dưới), và phần lớn cơ chế bảo mật của Apple đã bị tắt. Hệ thống được cài vào phân vùng `userdata`, vì vậy sẽ **xóa dữ liệu người dùng Android**.

## Những gì hoạt động

| Hạng mục | Trạng thái |
| --- | --- |
| Khởi động | Bootloader Xiaomi gốc → `fastboot boot` shim → XNU. Không ghi gì vào các phân vùng boot |
| CPU | 6 trong 8 lõi (sáu lõi Cortex-A55) qua PSCI, trang nhớ 16K, ngắt GICv3 và bộ định thời |
| Bộ nhớ | Khoảng 3,95 GiB từ vùng DDR phía trên |
| Lưu trữ | Trình điều khiển UFS riêng; phân vùng gốc iOS là volume HFS+ có journal, đọc/ghi được trong `userdata` |
| Userland iOS | Hệ thống tệp gốc và shared cache iPhone X 16.7.16 thực; launchd và các daemon hệ thống chạy được |
| Màn hình | Các dịch vụ IOSurface + IOMobileFramebuffer (`AppleCLCD`) trong kernel; CoreAnimation dựng hình bằng phần mềm; khung hình được chép vào framebuffer của bootloader. iOS nhận diện màn hình là màn hình iPhone X (1125×2436) |
| Giao diện | backboardd, SpringBoard, màn hình khóa, màn hình chính, Trung tâm điều khiển, Trung tâm thông báo, Cài đặt |
| Cảm ứng | Goodix GT9896 qua I²C (GENI), cấp nguồn qua RPMh, gửi sự kiện cảm ứng số hóa HID |
| Nút bấm | Nút nguồn và tăng/giảm âm lượng (PMIC qua SPMI) được gửi dưới dạng phím HID consumer; khóa và đánh thức hoạt động |
| Pin | Dịch vụ IOPMPowerSource (mức pin cố định 100%, có biểu tượng sạc; đã chuẩn bị đọc dữ liệu thực từ fuel gauge) |
| Nhận dạng thiết bị | iPhone X (`iPhone10,3` / `D22AP`): không có nút Home, giao diện điều hướng bằng cử chỉ |
| Kích hoạt | Dùng nhánh "Hactivation" gốc của mobileactivationd, được chọn qua trạng thái bảo mật trong device tree. Không liên hệ máy chủ Apple |

## Những gì chưa hoạt động

- **Điều hướng:** chưa thể thoát khỏi ứng dụng (cử chỉ về màn hình chính và nút Home của AssistiveTouch chưa có tác dụng).
- **Chưa có Wi-Fi, Bluetooth, mạng di động, âm thanh, camera, cảm biến, GPS, SEP / Face ID.** Các daemon tương ứng khởi động rồi gặp lỗi hoặc liên tục khởi chạy lại.
- **Chưa có GPU.** CPU dựng toàn bộ hình ảnh ở khoảng 20–30 fps. Hai lõi Cortex-A76 hiện chưa được sử dụng.
- **Ít ứng dụng.** Image chỉ có những thành phần nằm trên system volume. Không có App Store, không có Apple ID và một số trang Cài đặt còn trống.
- **Khởi động chậm:** mất khoảng 4 phút ở logo Apple.
- **Đã tắt bảo mật:** chính sách ký mã (AMFI) và sandbox được nới lỏng, AppleKeyStore chỉ là bản stub, không có bảo vệ dữ liệu. Không lưu dữ liệu cá nhân trên thiết bị.

## Quy trình khởi động

```
ABL (bootloader Xiaomi gốc, đã mở khóa)
  -> fastboot boot shim-boot.img              (tạm thời; không ghi gì vào phân vùng boot)
     -> shim: tự thiết lập MMU, đọc FDT hiện có, nạp payload từ ramdisk
        -> XNU Mach-O + Apple Device Tree (ADT) được tạo + boot-args
           -> XNU -> trình điều khiển UFS -> phân vùng gốc HFS+ trong userdata
              -> dyld + shared cache -> launchd -> daemon -> backboardd + SpringBoard
```

Không có cổng serial (trên bo mạch này, UART gỡ lỗi được nối như SPI). Kernel hiển thị console vào framebuffer mà ABL để lại tại `0x9c000000`, đồng thời lưu vòng log 4 MiB bền vững ở cuối `userdata`. Dùng OrangeFox recovery và `tools/sweet-log-pull.sh` để đọc log, không cần quay màn hình.

## Tự thực hiện

Bạn cần Redmi Note 10 Pro (`sweet`, bản quốc tế hoặc Ấn Độ, SM7150) với **bootloader đã mở khóa**, máy tính Linux và tài khoản GitHub để build kernel. Đây là quy trình chính xác đã dùng để tạo các ảnh chụp màn hình ở trên; biến thể máy hoặc firmware khác có thể cần điều chỉnh. **Toàn bộ dữ liệu trong `userdata` sẽ bị xóa.** Các phân vùng bootloader, recovery, modem và persist không bị động đến.

### 0. Sao lưu điện thoại

Khởi động tạm OrangeFox (hoặc recovery bất kỳ có adb root) và sao lưu ít nhất các phân vùng `persist`, `modemst1`, `modemst2`, `fsg`, `fsc`, `boot`, `dtbo`, `vbmeta`. Chúng chứa dữ liệu hiệu chuẩn riêng cho từng thiết bị. Không đưa các bản sao lưu này vào git; `.gitignore` đã loại trừ `backup/`, `dtb/` và `recovery/`.

Shim cần DTB gốc. Giải nén `boot.img` gốc của điện thoại:

```sh
python3 tools/unpack_bootv2.py backup/boot.img dtb/boot_unpacked   # -> dtb/boot_unpacked/dtb
```

### 1. Build kernel

Kernel được build trên runner macOS của GitHub bằng [blacktop/darwin-xnu-build](https://github.com/blacktop/darwin-xnu-build). Workflow tải xnu-8796, lần lượt áp dụng các bản vá trong `xnu/patches/`, đồng thời chuẩn bị mã nguồn libpthread, HFS và BearSSL mã nguồn mở đã được ghim phiên bản. Hãy fork repository (repository công khai được GitHub cấp miễn phí phút chạy macOS) rồi chạy:

```sh
gh workflow run xnu.yml -R YOU/ios-sweet
gh run download RUN_ID -R YOU/ios-sweet -n xnu-kernel -D xnu/out
```

Để kiểm tra bản vá cục bộ trước khi dùng một lượt CI, `tools/xnu-cc.py` chạy lại lệnh biên dịch từng tệp lấy từ log CI trước đó.

### 2. Tạo image phân vùng gốc iOS

Tải IPSW iOS 16.7.16 (20H392) của iPhone X (iPhone10,3) từ Apple. Sau đó, trên Linux, dùng `apfs-fuse`, `hfsprogs` và sudo:

```sh
# Các disk image OS, SystemOS và AppOS trong IPSW (xem tên trong BuildManifest.plist)
tools/mkiosroot.sh OS.dmg SystemOS.dmg AppOS.dmg ios16-root.img 16G
sudo fsck.hfsplus -fy ios16-root.img
sudo mount -t hfsplus -o loop,force ios16-root.img /mnt/iosroot
sudo python3 tools/sweet-root-tweaks.py /mnt/iosroot
sudo umount /mnt/iosroot
img2simg ios16-root.img ios16-root.simg
```

`mkiosroot.sh` chép volume OS và cả hai cryptex vào một volume HFS+ phân biệt chữ hoa/chữ thường và có journal. Script thêm các liên kết dyld cache, system keybag dạng thường và thư mục log mà các daemon cần. `sweet-root-tweaks.py` áp dụng các điều chỉnh bring-up: bỏ qua Setup, khởi tạo trạng thái kích hoạt, loại bỏ daemon baseband, tắt watchdog kết thúc các ứng dụng chạy chậm và các đường xử lý media bị crash loop, v.v. Phần đầu script giải thích từng thay đổi.

Công cụ tạo device tree chép `/product` từ device tree iPhone X thật, vì MobileGestalt cần node này. Chỉ cần trích xuất một lần, không phải tải toàn bộ IPSW:

```sh
python3 tools/remotezip.py IPSW_URL DeviceTree.d22ap.im4p research/ipsw-x/dt
ipsw img4 im4p extract research/ipsw-x/dt/Firmware/all_flash/DeviceTree.d22ap.im4p -o research/ipsw-x/d22ap.adt
```

### 3. Tạo boot image

Cần `aarch64-linux-gnu-gcc` và `mkbootimg`.

```sh
python3 tools/mkadt.py shim/out/sweet.adt --highmem
python3 tools/mkpayload.py xnu/out/kernel.development.sweet shim/out/sweet.adt shim/out/payload.bin \
    --cmdline 'debug=0xc serial=3 cpus=6 keepsyms=1 -enable_kprintf_spam -noprogress rd=ufsroot0 unentitled_ios_sim_launch=1 ignition_level=1 wdt_test=no_user_checkin ufsrw=1 rootrw=1 launchd_unsecure_cache=1 wdt=-1 sweetfb_noconsole=1 sweetfb_hz=30'
shim/build.sh ../shim/out/payload.bin      # -> shim/out/shim-boot.img
```

Ý nghĩa của một số boot-args ít hiển nhiên:

| Boot-arg | Tác dụng |
| --- | --- |
| `rd=ufsroot0 ufsrw=1 rootrw=1` | Dùng phân vùng `userdata` làm phân vùng gốc, cho phép ghi |
| `cpus=6` | Khởi động sáu lõi A55; `cpus=1` là phương án dự phòng an toàn |
| `launchd_unsecure_cache=1` | Cho phép launchd chấp nhận job cache mà không cần AMFI |
| `wdt=-1 wdt_test=no_user_checkin` | Tắt hardware watchdog |
| `sweetfb_noconsole=1` | Không vẽ chữ kernel đè lên giao diện. Log vẫn được ghi bền vững; panic vẫn được hiển thị |
| `sweetfb_hz=30` | Tần số cập nhật màn hình khi chép hình bằng CPU |
| `sweettouch=0`, `sweetkeys=0` | Tắt trình điều khiển cảm ứng hoặc nút bấm |

### 4. Ghi phân vùng gốc và khởi động

```sh
fastboot -S 512M flash userdata ios16-root.simg   # khoảng 7 phút; không rút cáp
# Fastboot của Xiaomi thường bị treo sau khi ghi image lớn: vào lại fastboot bằng Power + Volume down
fastboot boot shim/out/shim-boot.img
```

Lần khởi động đầu tiên mất khoảng 4–5 phút ở logo Apple, sau đó màn hình khóa sẽ xuất hiện. Vuốt lên để mở khóa. Để quay lại fastboot, nhấn giữ Power + Volume down.

### 5. Đọc log kernel

```sh
fastboot boot recovery/recovery.img        # OrangeFox, khởi động tạm thời
tools/sweet-log-pull.sh logs/boot.txt      # vòng log console 4 MiB ở cuối userdata
adb reboot bootloader
```

Log bao gồm báo cáo crash kèm backtrace (`CRASH name ...`), trace IOKit của backboardd và SpringBoard, cùng các dòng log `SWEET ...` của trình điều khiển. `tools/sweet-crash.py` symbolicate log dựa trên shared cache.

### QEMU

`tools/qemu-sweet.py` khởi động cùng kernel trên QEMU `virt` với phân vùng gốc RAM-disk thử nghiệm. Công cụ này hữu ích khi chỉ thay đổi kernel; xem `NOTES.md`.

## Cấu trúc repository

| Đường dẫn | Nội dung |
| --- | --- |
| `shim/` | Boot shim bare-metal (C + asm), đóng gói thành Android boot.img v2 |
| `xnu/patches/` | Chuỗi bản vá XNU (CI áp dụng theo thứ tự), cùng script chuẩn bị libpthread, HFS và BearSSL |
| `.github/workflows/xnu.yml` | CI build kernel |
| `tools/mkadt.py` | Tạo Apple Device Tree từ bố trí MMIO của sweet và danh tính iPhone X |
| `tools/mkpayload.py` | Đóng gói kernel + ADT + boot-args thành payload cho shim |
| `tools/mkiosroot.sh` | Tạo phân vùng gốc iOS HFS+ từ các image trong IPSW |
| `tools/sweet-root-tweaks.py` | Điều chỉnh phân vùng gốc cho bring-up (bỏ qua Setup, kích hoạt, daemon) |
| `tools/sweet-log-pull.sh`, `sweet-log.py` | Đọc log kernel bền vững từ recovery |
| `tools/sweet-crash.py` | Symbolicate báo cáo crash của console |
| `tools/xnu-cc.py` | Kiểm tra biên dịch một tệp cục bộ dựa trên log CI |
| `tools/qemu-sweet.py` | Khởi động thử trên QEMU, giải mã văn bản framebuffer |
| `tools/adt.py`, `remotezip.py`, `unpack_bootv2.py`, `sparsediff.py` | Các công cụ hỗ trợ |
| `NOTES.md` | Nhật ký kỹ thuật chi tiết: từng lần boot, crash, quyết định và thông tin phần cứng |

Không đưa vào git: bản sao lưu phân vùng, device tree trích xuất từ máy, recovery image, firmware và root image của Apple, cùng các build tree đã tải xuống hoặc tạo ra. Chúng có thể chứa số serial thiết bị, dữ liệu hiệu chuẩn hoặc tệp có bản quyền của Apple.

## Các bản vá kernel

| # | Nội dung |
| --- | --- |
| 0001–0009 | Tương thích toolchain, cấu hình máy SWEET, arm64 không PAC, stub cho các thành phần nội bộ của Apple |
| 0010–0018 | Console framebuffer giai đoạn sớm, sửa physmap, PRNG không cần corecrypto, device-tree platform expert, timer PPI, trình điều khiển CPU khởi động |
| 0019–0020 | Provider libpthread kernel mã nguồn mở của Apple; AES của BearSSL |
| 0021–0027 | Phân vùng gốc RAM-disk, mockfs, SHA-256, AMFI tối thiểu, HFS+ mã nguồn mở của Apple, MD5 |
| 0028–0034 | Trình điều khiển UFS host và thiết bị gốc, phân vùng gốc đọc/ghi, DMA trên 4 GiB |
| 0035–0045 | Entitlement, bindfs, AppleKeyStore stub, IOWatchdog, báo cáo crash của console |
| 0046 | Các dịch vụ IOSurface (IOCoreSurfaceRoot) và IOMobileFramebuffer (AppleCLCD) |
| 0047–0055 | Chẩn đoán: log bền vững, tee `/dev/null`, trace IOKit, chuỗi heap và lấy mẫu user stack khi crash; chính sách Sandbox nới lỏng; HFS rename-swap; AppleKeyStore selector |
| 0056–0057 | Giới hạn tốc độ chép khung hình lên màn hình; không dùng bộ phân giải danh tính bên ngoài |
| 0058 | Dịch vụ sự kiện HID. User client và hàng đợi sự kiện IOHIDFamily-1915.140.3 của Apple, tương thích với userland iOS 16.7 |
| 0059 | Danh tính iPhone X (`hw.product` / `hw.target` lấy từ device tree) |
| 0060 | Nút nguồn và âm lượng qua SPMI; cảm ứng qua GENI I²C |
| 0061 | Hiển thị độ phân giải màn hình là 1125×2436 |
| 0062 | Yêu cầu regulator RPMh để cấp nguồn cho cảm ứng; nguồn pin |
| 0063 | Sửa đóng gói FIFO GENI và triển khai giao thức Goodix GT9896 |
| 0064 | Cấp quyền PRIV_WORK_INTERVAL (khoảng làm việc CoreAnimation của UIKit) |
| 0065 | SMP: khởi động các lõi A55 phụ qua PSCI CPU_ON |
| 0066–0067 | Thông tin vùng lỗi khi crash; tắt console |
| 0068 | Ngữ nghĩa tra cứu IOSurface đã được ánh xạ |
| 0069 | Ghi log bền vững theo lô |

## Thông tin phần cứng chính

- RAM: payload dùng bank phía trên, `0x100000000` + `0xfcc00000` (khoảng 3,95 GiB), nằm ngoài các vùng carve-out được Qualcomm bảo vệ.
- GICv3 có security extension: timer sử dụng Group 1 IRQ (virtual timer INTID 19), không phải FIQ như trên Apple silicon.
- PSCI qua `smc`, timer 19,2 MHz, ARMv8.2 không có pointer authentication. MPIDR dùng Aff1 làm số lõi.
- Màn hình: chế độ video DSC 1080×2400, splash liên tục từ ABL, không cần kích hoạt làm tươi màn hình.
- Cảm ứng: Goodix GT9896 tại I²C `0x5d` trên QUP SE7 (`0xa84000`), được cấp nguồn bởi PM6150L LDO11 qua RPMh.
- Nút bấm: nút nguồn và giảm âm lượng nằm trên khối PM6150 PON; tăng âm lượng nằm trên PM6150L GPIO2 (SPMI SID 4).

Xem thêm trong [`NOTES.md`](NOTES.md).

## Ghi nhận

Dự án được xây dựng dựa trên các bản phát hành mã nguồn mở của Apple (xnu, IOHIDFamily, libpthread, hfs), [BearSSL](https://bearssl.org), [blacktop/darwin-xnu-build](https://github.com/blacktop/darwin-xnu-build), [ipsw](https://github.com/blacktop/ipsw), mã nguồn Linux kernel do Qualcomm/Xiaomi công bố để tra cứu thông tin phần cứng và [OrangeFox Recovery](https://orangefox.download). Bản thân iOS thuộc sở hữu của Apple và không được phân phối trong dự án này.
