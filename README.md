# 📸 SnapMaster for macOS

**SnapMaster** là ứng dụng native siêu nhẹ (~1MB) dành riêng cho macOS, tích hợp trọn gói bộ ba công cụ: **Chụp màn hình thông minh**, **Chỉnh sửa & Chú thích ảnh (Annotation & OCR)**, và **Quay video màn hình kèm âm thanh hệ thống (ScreenCaptureKit)**.

---

## ✨ Tính năng nổi bật

### 1. 🎯 Chụp màn hình (Screen Capture)
- **Chụp vùng chọn (Area Selection):** Kéo thả tự do với thước ngắm pixel và kính lúp Loupe phóng to toạ độ & màu sắc.
- **Chụp toàn màn hình (Full Screen):** Hỗ trợ đa màn hình Retina với tỉ lệ điểm ảnh gốc sắc nét.
- **Chụp cửa sổ (Window Capture):** Tự động phát hiện viền cửa sổ ứng dụng.
- **Floating Thumbnail (Popup góc màn hình):**
  - Xem trước ảnh chụp tương tự CleanShot X.
  - Nút thao tác nhanh: **Copy to Clipboard**, **Lưu file**, **Mở Editor**, **OCR trích xuất chữ**.
  - Tự động ẩn sau thời gian cài đặt hoặc khi bạn tương tác xong.

### 2. ✏️ Trình chỉnh sửa & Chú thích ảnh (Annotation Editor)
- **Công cụ vector:**
  - ↗️ **Mũi tên (Arrow)** sắc nét chỉ dẫn nội dung.
  - 🔲 **Hình khối:** Chữ nhật, hình tròn/elip, đường thẳng.
  - 🔢 **Step Counter (Đánh số 1, 2, 3...):** Tự động tăng số mỗi lần click để làm tài liệu hướng dẫn (tutorial).
  - 🔤 **Text Box:** Thêm chữ chú thích phong cách hiện đại.
  - 🖌️ **Bút vẽ tự do (Pen):** Vẽ tay mượt mà.
- **Công cụ bảo mật & thẩm mỹ cá nhân hóa:**
  - ⬛ **Che mờ / Pixelate:** Làm mờ tức thì vùng chứa mật khẩu, email, số thẻ hoặc thông tin nhạy cảm.
  - 🔦 **Spotlight:** Giữ sáng vùng quan trọng và làm mờ tối khu vực xung quanh.
  - ✨ **Khung viền thẩm mỹ (Beautify Framing):** Thêm nền Gradient (Ocean Blue, Sunset Purple, Dark Obsidian...), bo góc tròn, đổ bóng sang trọng giống Shottr / Xnapper.
  - 🔍 **Apple Vision OCR:** Nhận diện toàn bộ chữ viết trên ảnh chụp và copy vào Clipboard chỉ với 1 click.
  - ↩️ **Undo / Redo:** Hoàn tác các bước chỉnh sửa không giới hạn.

### 3. 🎥 Quay video màn hình (Screen Recorder)
- Sử dụng API hiện đại nhất của Apple: **ScreenCaptureKit** (macOS 13+).
- **Thu âm thanh kép:** Thu đồng thời **Microphone** và **Âm thanh hệ thống (System Audio)** trực tiếp không cần cài driver âm thanh ảo như BlackHole.
- **Thanh điều khiển nổi (Floating Recording Bar):** Hiển thị thời gian quay thực tế, nút Pause / Resume và Stop.
- **Xuất file:**
  - Xuất video chuẩn `.mp4` (H.264 / AAC) tương thích mọi nền tảng.
  - Hỗ trợ công cụ chuyển đổi sang ảnh động **GIF** tối ưu dung lượng.

### 4. 🔤 Quét chữ màn hình (Capture Text - Screen OCR)
- Chọn nhanh vùng văn bản trên màn hình (tài liệu, ảnh, trang web không cho copy, video...).
- Tự động nhận diện chữ tiếng Việt, tiếng Anh và copy thẳng vào Clipboard.
- Hiển thị Notification HUD xem trước nội dung vừa quét.

### 5. 📱 Quét mã QR & Barcode (Barcode Scanner)
- Quét mọi loại mã QR, Barcode (EAN-13, Code 128, Aztec, PDF417...) xuất hiện trên màn hình.
- Tự động giải mã và copy kết quả vào Clipboard.
- Nếu là đường link (URL), Notification HUD hiển thị nút **Mở liên kết** để mở trực tiếp trong trình duyệt web.

### 6. 🕒 Lịch sử hoạt động & Quản lý (History Manager)
- Tự động lưu trữ lịch sử: Ảnh chụp màn hình, Đoạn chữ đã OCR, Mã QR/Barcode đã quét, và Video quay màn hình.
- Giao diện tra cứu trực quan:
  - Tìm kiếm nhanh theo từ khóa nội dung hoặc tên file.
  - Phân loại theo tab (Tất cả, Ảnh, Chữ OCR, Mã QR, Video).
  - Nút Copy nhanh, Mở liên kết URL, Mở lại trong Editor, Xem trong Finder.
  - Xóa từng mục hoặc **Xóa toàn bộ lịch sử (Clear History)** có xác nhận an toàn.

### 7. ⚙️ Cá nhân hóa & Cài đặt (Personalization & Settings)
- **Đa ngôn ngữ:** Chuyển đổi tức thời giữa **Tiếng Việt** và **English**.
- **Tùy biến Theme:** Lựa chọn giữa **Theo hệ thống**, **Sáng (Light)**, và **Tối (Dark)** áp dụng ngay lập tức.
- **Thư mục lưu trữ:** Tùy chỉnh thư mục lưu mặc định (`~/Pictures/SnapMaster`).
- **Watermark:** Bật/tắt Watermark bản quyền cá nhân trên từng ảnh chụp.
- **Làm đẹp ảnh:** Cấu hình độ dày nét vẽ, màu sắc ưa thích và hiệu ứng khung viền.

### 8. 🔄 Tự động cập nhật (Auto-Update via GitHub Releases)
- Tự động kiểm tra bản cập nhật khi khởi động thông qua GitHub Releases API.
- Hỗ trợ kiểm tra thủ công từ Menu Bar hoặc trong Cửa sổ Cài đặt.
- Tự động tải file zip, giải nén và cập nhật trực tiếp tại chỗ (In-Place Update) mà không cần can thiệp thủ công.

---

## ⌨️ Phím tắt toàn cầu (Global Hotkeys)

| Phím tắt | Chức năng |
| :--- | :--- |
| **`⌘ + ⇧ + 1`** | Chụp vùng chọn màn hình (Area Capture) |
| **`⌘ + ⇧ + 2`** | Chụp toàn màn hình (Full Screen Capture) |
| **`⌘ + ⇧ + 3`** | Chụp cửa sổ ứng dụng (Window Capture) |
| **`⌘ + ⇧ + 4`** | Bật / Dừng quay video màn hình (Toggle Recording) |
| **`⌘ + ⇧ + 5`** | Quét chữ màn hình trực tiếp (Capture Text - OCR) |
| **`⌘ + ⇧ + 6`** | Quét mã QR & Barcode trên màn hình (Scan QR) |
| **`⌘ + ⇧ + H`** | Mở cửa sổ Lịch sử (Show History) |
| **`ESC`** | Hủy chụp khi đang ở màn hình chọn vùng |

---

## 🚀 Khởi chạy ứng dụng

### Chạy trực tiếp từ App Bundle:
```bash
open /Users/lehien/Projects/SnapMaster/SnapMaster.app
```
Hoặc mở Finder và kéo `SnapMaster.app` vào thư mục `/Applications` để dùng như mọi app Mac thông thường.

### Cấp quyền hệ thống (Lần đầu chạy):
Khi mở lần đầu, macOS sẽ hiển thị hộp thoại yêu cầu cấp quyền:
1. Vào **System Settings** -> **Privacy & Security** -> **Screen Recording** (Ghi màn hình).
2. Gạt bật cho phép **SnapMaster**.

---

## 🛠️ Công cụ phát triển & Tự động hóa (Developer Scripts)

1. **Biên dịch & Đóng gói ứng dụng:**
   ```bash
   ./bundle_app.sh [version]
   ```

2. **Tự động đồng bộ lên GitHub:**
   ```bash
   ./push.sh "Nội dung commit cập nhật"
   ```

3. **Phát hành phiên bản mới lên GitHub Releases:**
   ```bash
   ./release.sh 1.0.1 "Mô tả tính năng mới của bản 1.0.1"
   ```
   *(Script sẽ tự động build, tạo zip, tag git, tạo GitHub Release và upload file `SnapMaster.zip` để tất cả các máy đang cài SnapMaster tự động nhận bản cập nhật).*

File thực thi `.app` sẽ tự động được cập nhật tại `SnapMaster.app`.
