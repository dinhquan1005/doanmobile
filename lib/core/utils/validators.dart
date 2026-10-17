class AppValidators {
  AppValidators._();

  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  /// Số điện thoại di động Việt Nam (10 chữ số bắt đầu bằng 03, 05, 07, 08, 09 hoặc +84)
  static final RegExp _vnPhoneRegex = RegExp(
    r'^(0|\+84)(3|5|7|8|9)[0-9]{8}$',
  );

  static final RegExp _skuRegex = RegExp(r'^[A-Z0-9\-_]{3,40}$');

  static String? validateEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Vui lòng nhập địa chỉ email.';
    }
    if (!_emailRegex.hasMatch(trimmed)) {
      return 'Địa chỉ email không hợp lệ.';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    final raw = value ?? '';
    if (raw.isEmpty) {
      return 'Vui lòng nhập mật khẩu.';
    }
    if (raw.length < 6) {
      return 'Mật khẩu phải có ít nhất 6 ký tự.';
    }
    return null;
  }

  static String? validateVietnamPhone(String? value) {
    final cleaned = (value ?? '').replaceAll(' ', '');
    if (cleaned.isEmpty) {
      return 'Vui lòng nhập số điện thoại.';
    }
    if (!_vnPhoneRegex.hasMatch(cleaned)) {
      return 'Số điện thoại Việt Nam không hợp lệ (ví dụ: 0912345678).';
    }
    return null;
  }

  static String? validateRequired(String? value, {required String fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập $fieldName.';
    }
    return null;
  }

  static String? validateSku(String? value) {
    final trimmed = value?.trim().toUpperCase() ?? '';
    if (trimmed.isEmpty) {
      return 'Vui lòng nhập mã SKU.';
    }
    if (!_skuRegex.hasMatch(trimmed)) {
      return 'Mã SKU chỉ gồm chữ in hoa, số, dấu gạch ngang (3-40 ký tự).';
    }
    return null;
  }

  static String? validatePriceVnd(int? price) {
    if (price == null || price <= 0) {
      return 'Giá sản phẩm phải là số nguyên dương (VND).';
    }
    if (price % 1000 != 0 && price >= 1000) {
      return 'Giá VND nên là bội số của 1.000 ₫.';
    }
    return null;
  }
}