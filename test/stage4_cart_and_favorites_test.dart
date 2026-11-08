import 'package:electronic_store/app/app.dart';
import 'package:electronic_store/core/providers/firebase_providers.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:electronic_store/core/constants/firestore_collections.dart';
import 'package:electronic_store/core/errors/app_failure.dart';
import 'package:electronic_store/data/datasources/catalog_seed_service.dart';
import 'package:electronic_store/data/models/cart_model.dart';
import 'package:electronic_store/data/repositories/cart_repository.dart';
import 'package:electronic_store/data/repositories/favorites_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi_VN', null);
  });

  group('Cart Edge Cases, Integer VND Math & Stock Re-validation Tests', () {
    test(
        'Tính tạm tính, phí giao hàng, mã giảm giá bằng số nguyên VND và tạo payload không chứa giá client',
            () async {
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();
          final fakeFirestore = FakeFirebaseFirestore();
          await CatalogSeedService(fakeFirestore).seedInitialCatalogToFirestore();

          final cartRepo = CartRepository(
            firestore: fakeFirestore,
            sharedPreferences: prefs,
          );

          final now = DateTime.now().toUtc();
          // 1x CPU i5-13400F (4.690.000 ₫ - được chọn) + 1x Arduino UNO R4 (690.000 ₫ - bỏ chọn)
          final entries = <CartItemEntry>[
            CartItemEntry(
              productId: 'prod-cpu-i5-13400f',
              quantity: 1,
              isSelected: true,
              addedAt: now,
            ),
            CartItemEntry(
              productId: 'prod-diy-arduino-uno-r4-wifi',
              quantity: 1,
              isSelected: false,
              addedAt: now,
            ),
          ];

          final resolved =
          await cartRepo.resolveCartItemsWithLatestProducts(entries);
          final coupon = await cartRepo.validateCoupon(
            rawCode: 'LINHKIEN150K',
            currentSubtotal: 4690000,
          );

          final summary = CartSummary(
            items: resolved,
            appliedCoupon: coupon,
          );

          // Chỉ tính sản phẩm được chọn: 4.690.000 ₫
          expect(summary.subtotal, 4690000);
          expect(summary.discountAmount, 150000);
          // Sau giảm còn 4.540.000 ₫ >= 2.000.000 ₫ nên miễn phí giao hàng (0 ₫)
          expect(summary.estimatedShippingFee, 0);
          expect(summary.estimatedTotal, 4540000);
          expect(summary.canProceedToCheckout, isTrue);

          // Payload gửi lên server chỉ có productId và quantity, tuyệt đối không có trường price/total
          final serverPayload = summary.toServerCheckoutPayload();
          expect(serverPayload.length, 1);
          expect(serverPayload.first['productId'], 'prod-cpu-i5-13400f');
          expect(serverPayload.first['quantity'], 1);
          expect(serverPayload.first.containsKey('price'), isFalse);
        });

    test(
        'Từ chối mã giảm giá khi tổng tiền chưa đạt mức tối thiểu và tính phí ship khi đơn dưới 2 triệu',
            () async {
          final fakeFirestore = FakeFirebaseFirestore();
          await CatalogSeedService(fakeFirestore).seedInitialCatalogToFirestore();
          final cartRepo = CartRepository(firestore: fakeFirestore);

          // Đơn chỉ có 1 kit cảm biến 320.000 ₫ (< 3.000.000 ₫ của mã LINHKIEN150K)
          expect(
                () => cartRepo.validateCoupon(
              rawCode: 'LINHKIEN150K',
              currentSubtotal: 320000,
            ),
            throwsA(isA<ValidationFailure>()),
          );

          // Nhưng áp dụng được mã DIY10 (giảm 10% = 32.000 ₫ cho đơn từ 300.000 ₫)
          final diyCoupon = await cartRepo.validateCoupon(
            rawCode: 'DIY10',
            currentSubtotal: 320000,
          );
          final resolved = await cartRepo.resolveCartItemsWithLatestProducts([
            CartItemEntry(
              productId: 'prod-diy-sensor-kit-37in1',
              quantity: 1,
              isSelected: true,
              addedAt: DateTime.now().toUtc(),
            ),
          ]);

          final summary = CartSummary(items: resolved, appliedCoupon: diyCoupon);
          expect(summary.subtotal, 320000);
          expect(summary.discountAmount, 32000);
          // Dưới 2.000.000 ₫ nên phí vận chuyển là 30.000 ₫
          expect(summary.estimatedShippingFee, 30000);
          expect(summary.estimatedTotal, 320000 - 32000 + 30000);
        });

    test(
        'Phát hiện tồn kho trên Firestore giảm xuống thấp hơn số lượng trong giỏ và khóa nút đặt hàng',
            () async {
          final fakeFirestore = FakeFirebaseFirestore();
          await CatalogSeedService(fakeFirestore).seedInitialCatalogToFirestore();
          final cartRepo = CartRepository(firestore: fakeFirestore);

          // Giả sử kho của RTX 4060 trên Firestore giảm xuống chỉ còn 2 chiếc và giá đổi thành 8.000.000 ₫
          await fakeFirestore
              .collection(FirestoreCollections.products)
              .doc('prod-gpu-asus-rtx4060')
              .update({
            'stockQuantity': 2,
            'availableStock': 2,
            'salePrice': 8000000,
            'effectivePrice': 8000000,
          });

          // Trong giỏ hàng khách đang để số lượng 5
          final resolved = await cartRepo.resolveCartItemsWithLatestProducts([
            CartItemEntry(
              productId: 'prod-gpu-asus-rtx4060',
              quantity: 5,
              isSelected: true,
              addedAt: DateTime.now().toUtc(),
            ),
          ]);

          final summary = CartSummary(items: resolved);
          expect(resolved.first.latestUnitPrice, 8000000);
          expect(resolved.first.isExceedingStock, isTrue);
          expect(summary.hasSelectedItemsWithStockIssue, isTrue);
          expect(summary.canProceedToCheckout, isFalse);
        });

    test(
        'Hợp nhất giỏ hàng cục bộ (Guest) và Yêu thích cục bộ lên Cloud Firestore khi đăng nhập',
            () async {
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();
          final fakeFirestore = FakeFirebaseFirestore();

          final cartRepo = CartRepository(
            firestore: fakeFirestore,
            sharedPreferences: prefs,
          );
          final favRepo = FavoritesRepository(
            firestore: fakeFirestore,
            sharedPreferences: prefs,
          );

          // Khách chưa đăng nhập thêm 2 sản phẩm vào giỏ cục bộ và 1 sản phẩm yêu thích
          await cartRepo.saveGuestCart(
            items: [
              CartItemEntry(
                productId: 'prod-cpu-i5-13400f',
                quantity: 2,
                isSelected: true,
                addedAt: DateTime.now().toUtc(),
              ),
            ],
            appliedCouponCode: 'LINHKIEN150K',
          );
          await favRepo.saveGuestFavoriteIds({'prod-cpu-i5-13400f'});

          // Khách đăng nhập với userId = 'user_quan_1850'
          final mergedCart =
          await cartRepo.mergeGuestCartIntoUserCart('user_quan_1850');
          final mergedFavs =
          await favRepo.mergeGuestFavoritesIntoUser('user_quan_1850');

          expect(mergedCart.items.length, 1);
          expect(mergedCart.items.first.quantity, 2);
          expect(mergedCart.appliedCouponCode, 'LINHKIEN150K');
          expect(cartRepo.loadGuestCart().items, isEmpty);

          expect(mergedFavs.contains('prod-cpu-i5-13400f'), isTrue);
          expect(favRepo.loadGuestFavoriteIds(), isEmpty);
        });
  });

  group('Cart UI & Wide Layout Widget Tests', () {
    testWidgets('Giỏ hàng hiển thị đầy đủ trên cả màn hình di động và màn hình rộng', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final mockAuth = MockFirebaseAuth();
      final fakeFirestore = FakeFirebaseFirestore();
      await CatalogSeedService(fakeFirestore).seedInitialCatalogToFirestore();

      final cartRepo = CartRepository(
        firestore: fakeFirestore,
        sharedPreferences: prefs,
      );
      await cartRepo.saveGuestCart(
        items: [
          CartItemEntry(
            productId: 'prod-diy-arduino-uno-r4-wifi',
            quantity: 2,
            isSelected: true,
            addedAt: DateTime.now().toUtc(),
          ),
        ],
        appliedCouponCode: null,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            firebaseAuthProvider.overrideWithValue(mockAuth),
            firestoreProvider.overrideWithValue(fakeFirestore),
          ],
          child: const ElectronicStoreApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Mở tab Giỏ hàng
      await tester.tap(find.text('Giỏ hàng'));
      await tester.pumpAndSettle();

      // Kiểm tra sản phẩm trong giỏ và panel thanh toán trên layout điện thoại
      expect(find.textContaining('Bo mạch Arduino UNO R4 WiFi'), findsOneWidget);
      expect(find.byKey(const Key('cart_apply_coupon_button')), findsOneWidget);
      expect(find.byKey(const Key('proceed_to_checkout_button')), findsOneWidget);

      // Chuyển sang màn hình rộng (Tablet / Desktop: 1024x768)
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      await tester.pumpAndSettle();

      // Xác nhận cả danh sách sản phẩm và panel tính tiền hiển thị song song không bị crash BoxConstraints
      expect(find.textContaining('Bo mạch Arduino UNO R4 WiFi'), findsOneWidget);
      expect(find.byKey(const Key('cart_apply_coupon_button')), findsOneWidget);
      expect(find.byKey(const Key('proceed_to_checkout_button')), findsOneWidget);
      expect(find.text('Tiến hành đặt hàng'), findsOneWidget);
    });
  });

}
