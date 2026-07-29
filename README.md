# Dùng iPad (kẹt ở iOS 12) làm màn hình phụ cho Mac (macOS 26), qua cáp Lightning — miễn phí, tự host

**Đã build + chạy thật** trên iPad Air (Model A1475, iOS 12.5.8) qua cáp Lightning. Video H.264 + chạm + cuộn 2 ngón + con trỏ chuột đều hoạt động ổn định.

## Ý tưởng

Không dùng app trả phí (Duet Display, Luna Display...). Thay vào đó:

1. **Máy Mac**: build và chạy nguyên bản (không sửa gì) app mã nguồn mở
   **[OpenDisplay](https://github.com/peetzweg/opendisplay)** (GPL-3.0, miễn phí).
   App này đã làm đúng phần khó nhất: tạo virtual display ảo trên macOS
   (`CGVirtualDisplay`), chụp màn hình đó (`ScreenCaptureKit`), nén H.264
   phần cứng (`VideoToolbox`), và tự nói chuyện trực tiếp với `usbmuxd` của
   macOS để truyền qua cáp Lightning/USB-C — **không cần cài thêm công cụ
   nào như `iproxy`.**
2. **iPad**: OpenDisplay yêu cầu iPadOS 17+ nên **không cài được lên iPad
   iOS 12** của bạn. Vì vậy thư mục `iOS/` trong repo này là một **client
   iOS 12 viết riêng**, tự implement lại đúng giao thức mạng mà OpenDisplay
   dùng (đọc được từ mã nguồn công khai của họ), để nói chuyện với app Mac
   ở trên mà không cần sửa app Mac.

Vì Mac chỉ cần chạy app không sửa đổi, còn phần bạn thực sự "tự viết" chỉ là
app iPad (nhẹ hơn nhiều so với viết lại toàn bộ pipeline từ đầu).

## Cấu trúc repo

```
ipad12-second-screen/
  README.md
  LICENSE                 <- MIT, áp dụng cho iOS/ (code tự viết)
  iOS/                    <- client iOS 12, tự viết, MIT
    project.yml           <- cấu hình xcodegen
    App/
      AppDelegate.swift
      ReceiverViewController.swift  <- toàn màn hình hiển thị video + bắt chạm/cuộn + vẽ cursor sprite
      VideoReceiver.swift    <- lõi: nghe TCP, giải khung, decode H.264, gửi/nhận control message
      LaunchScreen.storyboard
      Assets.xcassets/
  Mac/                    <- git submodule, upstream OpenDisplay KHÔNG sửa, GPL-3.0
```

`Mac/` là **git submodule** trỏ thẳng vào repo gốc `peetzweg/opendisplay` —
không copy/sửa gì, để rõ ràng đây là code của tác giả khác (giữ nguyên
license GPL-3.0 của họ) và dễ `git submodule update --remote` khi họ ra bản
mới.

Yêu cầu tối thiểu: **iOS 12.0** (`iOS/project.yml` → `deploymentTarget`), đã
test thật trên iOS 12.5.8.

## Bước 0 — Clone kèm submodule

```bash
git clone --recurse-submodules https://github.com/cuongpham1/ipad-second-monitor-ios12-free.git
cd ipad-second-monitor-ios12-free
```

Nếu đã clone thường (thiếu `--recurse-submodules`):

```bash
git submodule update --init --recursive
```

## Bước 1 — Build app Mac (OpenDisplay, không sửa)

```bash
brew install xcodegen
cd Mac
echo "DEVELOPMENT_TEAM=YOUR_TEAM_ID" > .env   # xem Team ID ở developer.apple.com/account, mục Membership
./generate.sh
open OpenSidecar.xcodeproj
```

Trong Xcode: chọn scheme **OpenSidecarMac** → Run. Lần đầu chạy, macOS sẽ
xin quyền **Screen Recording** và **Accessibility** (System Settings →
Privacy & Security) — cấp cả hai, **quit hẳn app (Cmd+Q) rồi mở lại**
(bật toggle quyền không đủ, cần khởi động lại app mới nhận quyền mới), rồi
chạy lại.

(Có thể dùng luôn bản `.dmg` build sẵn ở
[Releases](https://github.com/peetzweg/opendisplay/releases/latest) thay vì
tự build, nếu bạn tin tưởng binary đã ký/notarize sẵn của tác giả.)

## Bước 2 — Build app iPad (thư mục `iOS/` trong repo này)

```bash
brew install xcodegen   # nếu chưa cài ở bước 1
cd iOS
xcodegen generate
open LegacyPadDisplay.xcodeproj
```

Trong Xcode:
1. Chọn target **LegacyPadDisplay** → tab **Signing & Capabilities** → chọn
   Team là Apple ID cá nhân của bạn.
2. Cắm iPad vào Mac bằng cáp Lightning, chọn iPad làm device đích ở thanh
   công cụ Xcode.
3. Nhấn Run. Lần đầu cài, vào **Cài đặt → General → VPN & Device
   Management** trên iPad để "Trust" developer certificate của bạn.

App sẽ hiện toàn màn hình đen với dòng chữ "Listening on :9000" ở dưới —
nghĩa là đang chờ Mac kết nối tới.

### Xcode báo "Failed to prepare the device for development"

Xcode mới không kèm sẵn **iOS DeviceSupport** cho bản iOS 12 cũ. Cần thêm
folder support đúng version vào
`~/Library/Developer/Xcode/iOS DeviceSupport/`, lấy từ repo cộng đồng như
[filsv/iOSDeviceSupport](https://github.com/filsv/iOSDeviceSupport) hoặc
[apptim/iPhoneOSDeviceSupport](https://github.com/apptim/iPhoneOSDeviceSupport)
(không cần đúng tuyệt đối build number, gần đúng minor version là được).
Copy folder vào đúng chỗ, quit hẳn Xcode, cắm lại iPad, mở lại.

### Cài/chạy qua CLI không cần mở Xcode (máy đời cũ)

`xcodebuild`/`devicectl` (công cụ mới, dùng CoreDevice) **không hỗ trợ cài
lên iOS 12** — báo lỗi kiểu "This device does not support acquiring a usage
assertion". Dùng [`ios-deploy`](https://github.com/ios-control/ios-deploy)
(API AMDevice cũ) thay thế:

```bash
brew install ios-deploy
xcodebuild build -project iOS/LegacyPadDisplay.xcodeproj -scheme LegacyPadDisplay \
  -destination 'generic/platform=iOS' -allowProvisioningUpdates
ios-deploy --bundle iOS/build/.../LegacyPadDisplay.app --justlaunch
```

### Apple ID miễn phí — app tự hết hạn sau 7 ngày

Giới hạn của Apple, không phải của project này. Sau 7 ngày, cắm cáp mở Xcode
(hoặc chạy lại `ios-deploy`) cài lại là dùng tiếp được. Muốn khỏi lặp lại,
cần Apple Developer Program trả phí ($99/năm) — ký được 1 năm.

## Bước 3 — Kết nối

1. Đảm bảo cả hai app đang chạy (Mac app đã cấp quyền Screen Recording +
   Accessibility; iPad app đang mở, cắm cáp Lightning).
2. Trong app Mac (OpenDisplay), chọn chế độ kết nối **USB** — vì app iPad
   của bạn có `id` và cổng 9000 giống hệt bản gốc, Mac app sẽ tự nhận diện
   qua `usbmuxd` như với một thiết bị OpenDisplay bình thường.
3. Nếu kết nối thành công, iPad sẽ đổi từ màn hình đen sang hiển thị hình
   ảnh macOS (kèm con trỏ chuột thật), và trong System Settings → Displays
   trên Mac sẽ xuất hiện một màn hình mới — kéo cửa sổ sang đó là dùng được.

## Nếu không kết nối được — chỗ cần kiểm tra trước

- **Không thấy display ảo mới trong System Settings → Displays**: gần như
  luôn là do thiếu quyền Screen Recording/Accessibility cho app Mac, hoặc
  cấp quyền xong nhưng chưa quit+mở lại app (xem Bước 1).
- Log console của app Mac (Xcode → View → Debug Area → Console khi chạy
  scheme OpenSidecarMac) sẽ cho biết nó có thấy device qua usbmuxd không.
- Đảm bảo app iPad đang ở foreground (iOS có thể tạm dừng NWListener khi
  app vào background — bản tối giản này chưa xử lý việc tự khởi động lại
  listener khi quay lại foreground như bản gốc).
- Nếu Mac app gửi một `updateRequired`/phiên bản không tương thích — bản
  OpenDisplay Mac mới có thể đổi giao thức. `VideoReceiver.swift` cố tình
  không gửi trường `pv` (protocol version) nên sẽ luôn được xem là
  "protocol 1", mà theo tài liệu của OpenDisplay thì mọi bản Mac hiện tại
  đều hỗ trợ ngược protocol 1.

## Tính năng đã có / chưa có

Có: video, chạm để click/kéo, vuốt 2 ngón để cuộn, **con trỏ chuột thật**
(vị trí + hình dạng, đồng bộ qua control message riêng, mượt).

Chưa có: bàn phím rời, xoay màn hình tự động khớp lại virtual display, đo
độ trễ, tự khởi động lại khi app vào background.

## Giấy phép

- `iOS/` (client iOS 12): MIT, xem [LICENSE](LICENSE).
- `Mac/`: submodule trỏ tới `peetzweg/opendisplay`, GPL-3.0, tác giả gốc giữ
  bản quyền — không sửa đổi, không vendor vào repo này.
