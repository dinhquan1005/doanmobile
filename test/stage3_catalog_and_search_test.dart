import 'package:electronic_store/app/app.dart';
import 'package:electronic_store/core/providers/firebase_providers.dart';
import 'package:electronic_store/data/datasources/catalog_seed_service.dart';
import 'package:electronic_store/data/models/product_filter.dart';
import 'package:electronic_store/data/repositories/catalog_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi_VN', null);
  });

  group('CatalogRepository & Firestore Query Tests', () {
    test(
        'Tìm kiếm theo SKU, lọc theo thương hiệu/khoảng giá và sắp xếp giá tăng dần chính xác',
            () async {
          final fakeFirestore = FakeFirebaseFirestore();
          final seedService = CatalogSeedService(fakeFirestore);
          await seedService.seedInitialCatalogToFirestore();

          final repo = CatalogRepository(firestore: fakeFirestore);

          // 1. Tìm kiếm chính xác theo mã SKU
          final skuSearch = await repo.queryProducts(
            filter: const ProductFilter(searchQuery: 'CPU-INTEL-I5-13400F'),
          );
          expect(skuSearch.products.length, 1);
          expect(skuSearch.products.first.effectivePrice, 4690000);

          // 2. Lọc theo thương hiệu ASUS và sắp xếp giá tăng dần
          final asusSorted = await repo.queryProducts(
            filter: const ProductFilter(
              brandId: 'asus',
              sortOption: ProductSortOption.priceAsc,
            ),
          );
          expect(asusSorted.products.length, 3);
          expect(
            asusSorted.products[0].effectivePrice <=
                asusSorted.products[1].effectivePrice,
            isTrue,
          );
          expect(
            asusSorted.products[1].effectivePrice <=
                asusSorted.products[2].effectivePrice,
            isTrue,
          );

          // 3. Lọc theo khoảng giá dưới 1.000.000 ₫ (chỉ có các linh kiện DIY)
          final diyBudget = await repo.queryProducts(
            filter: const ProductFilter(maxPrice: 1000000),
          );
          expect(diyBudget.products.isNotEmpty, isTrue);
          expect(
            diyBudget.products.every((p) => p.effectivePrice <= 1000000),
            isTrue,
          );
        });
  });

  group('Home, Search & Product Detail UI Widget Tests', () {
    testWidgets(
        'Hiển thị sản phẩm từ Firestore trên Trang chủ và mở màn hình Chi tiết sản phẩm',
            (WidgetTester tester) async {
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();
          final mockAuth = MockFirebaseAuth();
          final fakeFirestore = FakeFirebaseFirestore();

          await CatalogSeedService(fakeFirestore).seedInitialCatalogToFirestore();

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

          // Kiểm tra Trang chủ đã hiển thị khu vực Sản phẩm nổi bật và giá VND
          expect(find.text('Sản phẩm nổi bật'), findsOneWidget);
          expect(find.textContaining('4.690.000 ₫'), findsWidgets);

          // Bấm vào thanh tìm kiếm nhanh trên Trang chủ
          await tester.tap(find.byKey(const Key('home_quick_search_bar')));
          await tester.pumpAndSettle();

          // Nhập từ khóa "Arduino" vào ô tìm kiếm
          await tester.enterText(
            find.byKey(const Key('catalog_search_input')),
            'Arduino',
          );
          await tester.testTextInput.receiveAction(TextInputAction.search);
          await tester.pumpAndSettle();

          expect(
            find.textContaining('Bo mạch Arduino UNO R4 WiFi'),
            findsWidgets,
          );
        });
  });
}