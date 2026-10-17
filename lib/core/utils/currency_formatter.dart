import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _vndFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  static final NumberFormat _numberOnlyFormat = NumberFormat.decimalPattern('vi_VN');

  /// Định dạng số nguyên VND sang chuỗi hiển thị chuẩn Việt Nam.
  /// Ví dụ: 2590000 -> "2.590.000 ₫"
  static String formatVnd(int amount) {
    final formattedNumber = _numberOnlyFormat.format(amount);
    return '$formattedNumber ₫';
  }

  /// Định dạng số nguyên không kèm ký hiệu tiền tệ.
  /// Ví dụ: 2590000 -> "2.590.000"
  static String formatNumber(int amount) {
    return _numberOnlyFormat.format(amount);
  }

  /// Tính phần trăm giảm giá nguyên (0 - 100) từ giá gốc và giá khuyến mãi.
  static int calculateDiscountPercent({
    required int originalPrice,
    required int? salePrice,
  }) {
    if (salePrice == null || originalPrice <= 0 || salePrice >= originalPrice) {
      return 0;
    }
    final discount = ((originalPrice - salePrice) * 100) ~/ originalPrice;
    return discount.clamp(1, 99);
  }

  /// Chuyển chuỗi nhập liệu có dấu chấm/phẩy sang số nguyên VND an toàn.
  static int? tryParseVnd(String rawInput) {
    final digitsOnly = rawInput.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      return null;
    }
    return int.tryParse(digitsOnly);
  }

  /// Giữ hàm truy cập formatter gốc khi cần dùng cho biểu đồ
  static NumberFormat get rawFormatter => _vndFormat;
}