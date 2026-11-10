# Electronic Store — Ứng dụng Thương mại Điện tử Linh kiện Máy tính & Phụ kiện PC

<p align="center">
  <strong>Đồ án môn học: Lập trình trên thiết bị di động (CMP177)</strong>
</p>

---

## 📌 Giới thiệu đề tài

**Electronic Store** là ứng dụng di động thương mại điện tử chuyên biệt cho lĩnh vực linh kiện máy tính, phần cứng PC và thiết bị DIY. Ứng dụng được xây dựng trên nền tảng **Flutter & Dart**, kết hợp nền tảng backend **Google Firebase** (Firebase Authentication, Cloud Firestore NoSQL).

Dự án áp dụng kiến trúc phân tầng theo tính năng (**Feature-First Architecture**) cùng thư viện quản lý trạng thái **Riverpod** và điều hướng **GoRouter**, mang lại trải nghiệm mượt mà, nhất quán và độ ổn định cao.

---

## 🚀 Tính năng nổi bật

### 1. Phân hệ Khách hàng (Customer)
- **Xác thực & Tài khoản:**
  - Đăng ký, đăng nhập tài khoản bằng Email & Mật khẩu (kiểm tra định dạng, bảo mật mật khẩu).
  - Đăng nhập nhanh bằng tài khoản Google (OAuth 2.0).
  - Khôi phục mật khẩu qua Email (Firebase Auth Password Reset).
  - Quản lý hồ sơ cá nhân và lịch sử giao dịch.
- **Khám phá & Tìm kiếm sản phẩm:**
  - Trang chủ trực quan: Banner khuyến mãi, danh mục linh kiện, Flash Sale giá sốc.
  - Phân loại danh mục chuyên sâu: CPU, VGA, Bo mạch chủ (Mainboard), RAM, Ổ cứng (SSD/HDD), Nguồn (PSU), Vỏ case, Màn hình & Gear.
  - Tìm kiếm linh hoạt theo từ khóa tên sản phẩm hoặc mã SKU linh kiện.
  - Bộ lọc sản phẩm đa tiêu chí: Lọc theo khoảng giá, theo thương hiệu (ASUS, MSI, GIGABYTE, Intel, AMD...) và tình trạng tồn kho.
  - Màn hình chi tiết sản phẩm: Thư viện hình ảnh sắc nét, bảng thông số kỹ thuật (Specs) đầy đủ và kiểm tra số lượng tồn kho theo thời gian thực.
- **Sản phẩm Yêu thích (Wishlist):**
  - Đánh dấu sản phẩm yêu thích ngay trên thẻ linh kiện.
  - Lưu trữ offline cho khách vãng lai bằng SharedPreferences và tự động đồng bộ hóa lên Cloud Firestore khi đăng nhập.
- **Giỏ hàng & Khuyến mãi:**
  - Thêm, bớt, cập nhật số lượng linh kiện trực tiếp trong giỏ.
  - Tùy chọn mua từng món hàng hoặc toàn bộ giỏ hàng.
  - Áp dụng mã giảm giá (Voucher) theo số tiền cố định hoặc phần trăm.
- **Đặt hàng & Quản lý đơn hàng:**
  - Nhập thông tin người nhận, địa chỉ giao hàng và phương thức thanh toán khi nhận hàng (COD).
  - Cơ chế **Idempotency Key** chống đặt trùng lặp khi bấm nút liên tục.
  - Tự động trừ tồn kho bằng **Firestore Transaction**, đảm bảo tính toàn vẹn dữ liệu khi nhiều người cùng mua.
  - Theo dõi trạng thái đơn hàng (Chờ xử lý, Đang giao, Đã giao, Đã hủy).
  - Cho phép hủy đơn hàng khi đang chờ xử lý và tự động hoàn trả số lượng linh kiện về kho.

### 2. Phân hệ Quản trị viên (Admin Panel)
- **Bảng điều khiển (Dashboard):**
  - Thống kê tổng số lượng sản phẩm, cảnh báo linh kiện sắp hết hoặc đã hết hàng, tổng số đơn hàng và ước tính giá trị kho hàng.
- **Quản lý sản phẩm (CRUD):**
  - Thêm mới linh kiện kèm thông số kỹ thuật và hình ảnh.
  - Chỉnh sửa thông tin, giá bán và điều chỉnh số lượng tồn kho.
  - Xóa linh kiện hoặc chuyển trạng thái ngừng kinh doanh.

---

## 🛠 Công nghệ sử dụng (Tech Stack)

| Thành phần | Công nghệ / Thư viện | Mục đích sử dụng |
| :--- | :--- | :--- |
| **Framework** | Flutter 3.x / Dart 3.x | Xây dựng giao diện ứng dụng di động đa nền tảng |
| **State Management** | lutter_riverpod: ^2.6.1 | Quản lý trạng thái ứng dụng reactive, dependency injection |
| **Navigation** | go_router: ^14.8.1 | Định tuyến khai báo với StatefulShellRoute (5 tabs) và Route Guards |
| **Backend & Database** | Firebase Authentication, Cloud Firestore | Xác thực người dùng, lưu trữ và đồng bộ dữ liệu thời gian thực |
| **Local Storage** | shared_preferences: ^2.5.0 | Lưu trữ offline giỏ hàng khách và danh sách yêu thích |
| **Media & UI Support** | cached_network_image, image_picker, intl | Bộ nhớ đệm ảnh, tải ảnh sản phẩm, định dạng tiền tệ VNĐ và ngày tháng |
| **Testing** | lutter_test, ake_cloud_firestore, irebase_auth_mocks | Kiểm thử tự động đơn vị (Unit Test) và giao diện (Widget Test) |

---

## 📂 Cấu trúc thư mục (Feature-First Architecture)

`	ext
lib/
├── app/
│   ├── app.dart                    # Widget khởi chạy ứng dụng chính (MaterialApp)
│   ├── router.dart                 # Cấu hình định tuyến GoRouter & Route Guards
│   └── theme.dart                  # Cấu hình chủ đề giao diện (Color palette, Typography)
├── core/
│   ├── constants/                  # Hằng số hệ thống, tên collection Firestore
│   ├── errors/                     # Xử lý ngoại lệ và thông báo lỗi ứng dụng
│   ├── providers/                  # Các Provider dùng chung (Firebase, SharedPreferences)
│   └── utils/                      # Tiện ích định dạng tiền tệ, ngày giờ, validator
├── data/
│   ├── models/                     # Data models (Product, Cart, Order, User, Voucher...)
│   └── repositories/               # Tầng dữ liệu tương tác với Firebase & Local Storage
└── features/
    ├── admin/                      # Module Quản trị viên (Dashboard, CRUD sản phẩm)
    ├── auth/                       # Module Xác thực (Đăng nhập, Đăng ký, Quên mật khẩu)
    ├── cart/                       # Module Giỏ hàng & áp dụng Voucher
    ├── catalog/                    # Module Danh mục, Tìm kiếm & Lọc sản phẩm
    ├── checkout/                   # Module Đặt hàng & Thanh toán
    ├── home/                       # Module Màn hình chính (Banner, Flash Sale)
    ├── orders/                     # Module Lịch sử & Theo dõi đơn hàng
    ├── shell/                      # Màn hình Shell chứa 5 tab điều hướng chính
    └── wishlist/                   # Module Danh sách linh kiện yêu thích
`

---

## ⚙️ Hướng dẫn cài đặt và chạy ứng dụng

### 1. Yêu cầu môi trường
- Flutter SDK: ^3.24.0 hoặc mới hơn
- Dart SDK: ^3.5.0 hoặc mới hơn
- Android Studio / VS Code
- Thiết bị thật Android hoặc máy ảo Android (hỗ trợ Google Play Services)

### 2. Các bước khởi chạy
`ash
# 1. Clone repository về máy
git clone https://github.com/dinhquan1005/doanmobile.git

# 2. Di chuyển vào thư mục dự án
cd doanmobile

# 3. Cài đặt các dependencies
flutter pub get

# 4. Kiểm tra mã nguồn
flutter analyze

# 5. Chạy toàn bộ các bài kiểm thử tự động
flutter test

# 6. Khởi chạy ứng dụng trên thiết bị
flutter run
`

---

## 🧪 Kết quả kiểm thử tự động
Dự án đã thiết lập các bộ kiểm thử tự động bao phủ toàn diện các chức năng cốt lõi:
- stage1_theme_and_data_models_test.dart: Kiểm tra khởi tạo models, JSON serialization và theme.
- stage2_auth_and_navigation_test.dart: Kiểm tra luồng xác thực đăng nhập, đăng ký và bảo vệ định tuyến.
- stage3_catalog_and_search_test.dart: Kiểm tra duyệt danh mục, tìm kiếm và bộ lọc đa tiêu chí.
- stage4_cart_and_voucher_test.dart: Kiểm tra tính toán giỏ hàng, cập nhật số lượng và chiết khấu voucher.
- stage5_order_and_transaction_test.dart: Kiểm tra quy trình checkout, trừ tồn kho và hủy đơn hoàn kho.
- stage6_admin_and_stock_test.dart: Kiểm tra phân hệ quản trị, thống kê KPI và CRUD linh kiện.

Kết quả thực nghiệm: **20/20 test cases vượt qua (Passed 100%)**.

---

## 👤 Tác giả & Thông tin đồ án
- **Học phần:** Lập trình trên thiết bị di động (CMP177)
- **Sinh viên thực hiện:** Đinh Quân ([@dinhquan1005](https://github.com/dinhquan1005))
- **Mã nguồn:** [github.com/dinhquan1005/doanmobile](https://github.com/dinhquan1005/doanmobile)