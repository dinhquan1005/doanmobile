import 'package:electronic_store/app/app.dart';
import 'package:electronic_store/core/constants/firestore_collections.dart';
import 'package:electronic_store/core/providers/firebase_providers.dart';
import 'package:electronic_store/features/admin/screens/admin_product_form_screen.dart';
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

  group('Stage 6 — Admin Dashboard & Catalog Seeding Tests', () {
    testWidgets('Hiển thị thống kê Admin, nạp dữ liệu mẫu và hiển thị danh sách tồn kho',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final fakeFirestore = FakeFirebaseFirestore();

      final mockAdminUser = MockUser(
        uid: 'admin_test_id',
        email: 'admin@electronicstore.vn',
        displayName: 'Quản trị viên',
      );
      final mockAuth = MockFirebaseAuth(signedIn: true, mockUser: mockAdminUser);

      // Đưa dữ liệu user với role 'admin' vào Firestore
      await fakeFirestore.collection(FirestoreCollections.users).doc('admin_test_id').set({
        'email': 'admin@electronicstore.vn',
        'fullName': 'Quản trị viên',
        'role': 'admin',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

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

      // Mở tab Tài khoản
      await tester.tap(find.text('Tài khoản'));
      await tester.pumpAndSettle();

      // Kiểm tra mục Khu vực Quản trị hiển thị đối với tài khoản Admin
      expect(find.text('Khu vực Quản trị (Admin Panel)'), findsOneWidget);

      // Bấm vào khu vực Quản trị để mở Admin Dashboard
      await tester.tap(find.text('Khu vực Quản trị (Admin Panel)'));
      await tester.pumpAndSettle();

      // Kiểm tra tiêu đề trang Admin
      expect(find.text('Bảng quản trị (Admin Dashboard)'), findsOneWidget);
      expect(find.text('Sản phẩm'), findsOneWidget);
      expect(find.text('Đơn hàng'), findsOneWidget);
      expect(find.text('Danh mục'), findsOneWidget);

      // Nhấn nút nạp dữ liệu mẫu
      final seedButton = find.byKey(const Key('admin_seed_data_button'));
      expect(seedButton, findsOneWidget);
      await tester.tap(seedButton);
      await tester.pumpAndSettle();

      // Sau khi nạp, các linh kiện phải được hiển thị trong danh sách theo dõi tồn kho
      expect(find.textContaining('Theo dõi tồn kho linh kiện'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.textContaining('CPU-INTEL-I5-13400F'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('CPU-INTEL-I5-13400F'), findsOneWidget);
    });

    testWidgets('Thêm linh kiện mới qua form Admin và lưu thành công vào Firestore',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final fakeFirestore = FakeFirebaseFirestore();

      final mockAdminUser = MockUser(
        uid: 'admin_test_id',
        email: 'admin@electronicstore.vn',
        displayName: 'Quản trị viên',
      );
      final mockAuth = MockFirebaseAuth(signedIn: true, mockUser: mockAdminUser);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            firebaseAuthProvider.overrideWithValue(mockAuth),
            firestoreProvider.overrideWithValue(fakeFirestore),
          ],
          child: const MaterialApp(
            home: AdminProductFormScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thêm mới linh kiện PC / DIY'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('admin_product_name_input')),
        'Card màn hình ASUS Dual RTX 4070 Super 12GB',
      );
      await tester.enterText(
        find.byKey(const Key('admin_product_sku_input')),
        'VGA-ASUS-RTX4070S-12G',
      );
      await tester.enterText(
        find.byKey(const Key('admin_product_price_input')),
        '17990000',
      );
      await tester.enterText(
        find.byKey(const Key('admin_product_stock_input')),
        '8',
      );

      await tester.tap(find.byKey(const Key('admin_save_product_button')));
      await tester.pumpAndSettle();

      final productsSnap =
          await fakeFirestore.collection(FirestoreCollections.products).get();
      expect(productsSnap.docs.isNotEmpty, isTrue);
      final savedProduct = productsSnap.docs.first.data();
      expect(savedProduct['sku'], 'VGA-ASUS-RTX4070S-12G');
      expect(savedProduct['price'], 17990000);
      expect(savedProduct['stockQuantity'], 8);
    });
  });
}

