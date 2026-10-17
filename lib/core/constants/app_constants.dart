class AppConstants {
  AppConstants._();

  static const String appName = 'Electronic Store';
  static const String appTagline = 'Linh kiện PC & Điện tử DIY chính hãng';
  static const String defaultLocale = 'vi_VN';
  static const String currencySymbol = '₫';
  static const String currencyCode = 'VND';

  /// Múi giờ chuẩn Việt Nam (UTC+7)
  static const Duration vietnamTimeZoneOffset = Duration(hours: 7);

  /// Cấu hình phân trang mặc định cho Firestore
  static const int defaultPageSize = 20;
  static const int homeSectionLimit = 8;

  /// Cấu hình vận chuyển mặc định (Đơn vị: VND - kiểu int)
  static const int defaultFreeShippingThreshold = 2000000;
  static const int defaultStandardShippingFee = 30000;
  static const int defaultExpressShippingFee = 60000;

  /// Giới hạn tệp tải lên Firebase Storage (5 MB)
  static const int maxUploadImageSizeBytes = 5 * 1024 * 1024;

  /// Thời gian giữ tồn kho cho đơn thanh toán trực tuyến (15 phút)
  static const int inventoryReservationMinutes = 15;

  /// Các khóa lưu trữ cục bộ trong SharedPreferences
  static const String prefThemeModeKey = 'pref_theme_mode';
  static const String prefGuestCartKey = 'pref_guest_cart_items';
  static const String prefRecentProductsKey = 'pref_recent_product_ids';
}