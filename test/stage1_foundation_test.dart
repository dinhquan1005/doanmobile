import 'package:electronic_store/app/app.dart';
import 'package:electronic_store/core/utils/currency_formatter.dart';
import 'package:electronic_store/core/utils/date_time_formatter.dart';
import 'package:electronic_store/core/utils/validators.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi_VN', null);
  });

  group('CurrencyFormatter VND Tests', () {
    test('Định dạng số nguyên VND chính xác theo chuẩn Việt Nam', () {
      expect(CurrencyFormatter.formatVnd(0), '0 ₫');
      expect(CurrencyFormatter.formatVnd(2590000), '2.590.000 ₫');
      expect(CurrencyFormatter.formatVnd(34990000), '34.990.000 ₫');
    });

    test('Tính phần trăm giảm giá chính xác bằng số nguyên', () {
      expect(
        CurrencyFormatter.calculateDiscountPercent(
          originalPrice: 1000000,
          salePrice: 850000,
        ),
        15,
      );
      expect(
        CurrencyFormatter.calculateDiscountPercent(
          originalPrice: 1000000,
          salePrice: null,
        ),
        0,
      );
      expect(
        CurrencyFormatter.calculateDiscountPercent(
          originalPrice: 1000000,
          salePrice: 1000000,
        ),
        0,
      );
    });

    test('Chuyển đổi chuỗi tiền tệ về số nguyên VND an toàn', () {
      expect(CurrencyFormatter.tryParseVnd('2.590.000 ₫'), 2590000);
      expect(CurrencyFormatter.tryParseVnd('abc'), isNull);
    });
  });

  group('DateTimeFormatter Vietnam Timezone Tests', () {
    test('Chuyển đổi giờ UTC sang múi giờ Việt Nam (UTC+7) chính xác', () {
      final utcTime = DateTime.utc(2026, 10, 17, 7, 30);
      expect(DateTimeFormatter.formatDateTime(utcTime), '17/10/2026 14:30');
      expect(DateTimeFormatter.formatDate(utcTime), '17/10/2026');
      expect(DateTimeFormatter.formatTime(utcTime), '14:30');
    });
  });

  group('AppValidators Input Validation Tests', () {
    test('Kiểm tra số điện thoại Việt Nam hợp lệ và không hợp lệ', () {
      expect(AppValidators.validateVietnamPhone('0912345678'), isNull);
      expect(AppValidators.validateVietnamPhone('+84987654321'), isNull);
      expect(AppValidators.validateVietnamPhone('0123456789'), isNotNull);
      expect(AppValidators.validateVietnamPhone('12345'), isNotNull);
    });

    test('Kiểm tra mã SKU và giá VND', () {
      expect(AppValidators.validateSku('CPU-INTEL-I5-13400F'), isNull);
      expect(AppValidators.validateSku('ab'), isNotNull);
      expect(AppValidators.validatePriceVnd(150000), isNull);
      expect(AppValidators.validatePriceVnd(0), isNotNull);
      expect(AppValidators.validatePriceVnd(-50000), isNotNull);
    });
  });

  group('ElectronicStoreApp Widget Smoke Test', () {
    testWidgets('Khởi chạy ứng dụng và hiển thị định dạng VND trên màn hình',
            (WidgetTester tester) async {
          await tester.pumpWidget(
            const ProviderScope(
              child: ElectronicStoreApp(),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Electronic Store'), findsWidgets);
          expect(
            find.text('Kiểm tra định dạng VND: 3.490.000 ₫'),
            findsOneWidget,
          );
        });
  });
}