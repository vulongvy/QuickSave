# HƯỚNG DẪN TỰ TẠO PHÍM TẮT TẢI VIDEO TRÊN IPHONE (100% SẠCH, 0 QUẢNG CÁO)

---

## I. NGUYÊN LÝ HOẠT ĐỘNG
Khi bạn bấm **Chia sẻ** từ bất kỳ ứng dụng nào (YouTube, Facebook, TikTok, Instagram, Safari...), Phím tắt sẽ:
1. Lấy đường link video.
2. Gửi link tới máy chủ bóc tách sạch (Backend Python/yt-dlp của bạn).
3. Nhận trực tiếp file `.mp4` nguyên gốc (đã gộp đủ tiếng + hình ảnh chất lượng cao).
4. Tự động lưu vào **Album Ảnh (Photos)** trên iPhone.

---

## II. CÁCH TẠO PHÍM TẮT TRÊN IPHONE (CHỈ MẤT 2 PHÚT)

Mở ứng dụng **Phím tắt (Shortcuts)** có sẵn trên iPhone của bạn và làm theo các bước sau:

### Bước 1: Tạo phím tắt mới
1. Bấm vào dấu **`+`** ở góc trên cùng bên phải.
2. Bấm vào tên phím tắt ở trên cùng -> Chọn **Đổi tên** thành: `Tải Video Sạch` (hoặc tên tùy thích).
3. Đổi icon/màu sắc tùy ý (ví dụ hình mũi tên tải xuống màu xanh).

### Bước 2: Bật "Hiển thị trong bảng chia sẻ"
1. Bấm vào biểu tượng thông tin **`(i)`** ở cạnh dưới cùng màn hình (hoặc góc trên tùy phiên bản iOS).
2. Bật công tắc: **Hiển thị trong bảng chia sẻ** (*Show in Share Sheet*).
3. Quay lại màn hình soạn thảo phím tắt, bạn sẽ thấy dòng đầu tiên:
   - *"Nhận [Bất kỳ] đầu vào từ Bảng chia sẻ"*
   - Bấm vào chữ **[Bất kỳ]** ➔ Bỏ chọn hết, chỉ tích chọn: **Đường liên kết (URLs)**, **Văn bản (Text)**, **Trang web Safari**.

### Bước 3: Thêm các khối lệnh (Chỉ 4 khối)

#### 👉 Khối lệnh 1: Nhận diện URL
- Bấm **Thêm tác vụ** (Add Action).
- Gõ tìm kiếm: **`Lấy URL từ`** (*Get URLs from Input*).
- Chọn tác vụ này (nó sẽ tự nhận link từ bảng chia sẻ).

#### 👉 Khối lệnh 2: Mã hóa đường link (URL Encode)
- Gõ tìm kiếm: **`Mã hóa URL`** (*URL Encode*).
- Đặt tham số là: Mã hóa `URLs` (từ Khối lệnh 1).

#### 👉 Khối lệnh 3: Tải file từ Server
- Gõ tìm kiếm: **`Lấy nội dung của URL`** (*Get Contents of URL*).
- Tại ô nhập URL, bạn điền địa chỉ API server của bạn kèm tham số, ví dụ:
  ```text
  https://dia-chi-server-cua-ban.com/download?url=[Văn bản được mã hóa theo URL]
  ```
  *(Chạm vào bàn phím để chọn biến `Văn bản được mã hóa theo URL` gắn vào sau dấu `=`)*.

#### 👉 Khối lệnh 4: Lưu vào Album ảnh
- Gõ tìm kiếm: **`Lưu vào album ảnh`** (*Save to Photo Album*).
- Nó sẽ tự động nhận kết quả từ Khối 3 (`Nội dung của URL`) để lưu vào Cuộn camera.

*(Tùy chọn thêm Khối 5)*:
- Gõ tìm kiếm: **`Hiển thị thông báo`** (*Show Notification*).
- Nội dung: `Đã lưu video vào Album ảnh thành công!`.

Bấm **Xong (Done)** ở góc trên cùng để lưu phím tắt.

---

## III. CÁCH TRIỂN KHAI BACKEND CỦA BẠN (HOÀN TOÀN MIỄN PHÍ)

Để phím tắt có thể hoạt động 24/7 mọi lúc mọi nơi kể cả khi dùng 4G/5G, bạn chỉ cần đưa mã nguồn `server.py` lên dịch vụ Cloud miễn phí:

### Cách 1: Deploy lên Render.com (Khuyên dùng - Miễn phí vĩnh viễn)
1. Đăng ký tài khoản miễn phí tại: [https://render.com](https://render.com)
2. Kết nối với tài khoản GitHub và tải thư mục dự án này lên một repository cá nhân.
3. Trên Render: Chọn **New Web Service** ➔ Chọn repo vừa tải lên.
4. Render sẽ tự phát hiện `Dockerfile` hoặc bạn chọn:
   - **Environment**: Python
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `gunicorn -w 2 -b 0.0.0.0:$PORT server:app`
5. Bấm **Deploy**. Sau 2-3 phút, Render sẽ cấp cho bạn 1 đường link miễn phí dạng:
   `https://ten-ung-dung-cua-ban.onrender.com`
6. Bạn chỉ cần thay link đó vào **Khối lệnh 3** trong Phím tắt trên iPhone!

### Cách 2: Chạy thử nghiệm ngay trên máy tính cá nhân
Nếu máy tính của bạn và iPhone cùng kết nối vào một mạng Wi-Fi ở nhà:
1. Chạy server trên máy tính:
   ```powershell
   .\.venv\Scripts\python.exe server.py
   ```
2. Xem IP mạng LAN của máy tính (ví dụ: `192.168.1.15`).
3. Trong Khối lệnh 3 của Phím tắt iPhone, điền:
   `http://192.168.1.15:8000/download?url=[Văn bản được mã hóa theo URL]`
4. Thử nghiệm tải ngay lập tức trên iPhone!
