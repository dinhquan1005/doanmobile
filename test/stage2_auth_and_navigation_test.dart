import 'package:electronic_store/app/app.dart';
import 'package:electronic_store/core/constants/firestore_collections.dart';
import 'package:electronic_store/core/providers/firebase_providers.dart';
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

  testWidgets(
      'Điều hướng 5 tab BottomNavigationBar và Đăng ký tài khoản lưu vào Firestore',
          (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final mockAuth = MockFirebaseAuth();
        final fakeFirestore = FakeFirebaseFirestore();

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

        // 1. Kiểm tra đủ 5 tab trên thanh điều hướng dưới cùng
        expect(find.text('Trang chủ'), findsOneWidget);
        expect(find.text('Danh mục'), findsOneWidget);
        expect(find.text('Giỏ hàng'), findsOneWidget);
        expect(find.text('Đơn hàng'), findsOneWidget);
        expect(find.text('Tài khoản'), findsOneWidget);

        // 2. Chuyển sang tab Tài khoản (khi chưa đăng nhập)
        await tester.tap(find.text('Tài khoản'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('open_register_button')), findsOneWidget);

        // 3. Mở màn hình Đăng ký và tạo tài khoản mới
        await tester.tap(find.byKey(const Key('open_register_button')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('register_name_field')),
          'Trương Đình Quân',
        );
        await tester.enterText(
          find.byKey(const Key('register_email_field')),
          'quan@electronicstore.vn',
        );
        await tester.enterText(
          find.byKey(const Key('register_phone_field')),
          '0912345678',
        );
        await tester.enterText(
          find.byKey(const Key('register_password_field')),
          'MatKhau123',
        );
        await tester.enterText(
          find.byKey(const Key('register_confirm_password_field')),
          'MatKhau123',
        );

        await tester.tap(find.byKey(const Key('register_submit_button')));
        await tester.pumpAndSettle();

        // 4. Kiểm tra document người dùng đã được tạo trong Cloud Firestore
        final usersSnapshot =
        await fakeFirestore.collection(FirestoreCollections.users).get();
        expect(usersSnapshot.docs.length, 1);
        final savedData = usersSnapshot.docs.first.data();
        expect(savedData['fullName'], 'Trương Đình Quân');
        expect(savedData['email'], 'quan@electronicstore.vn');
        expect(savedData['phoneNumber'], '0912345678');
        expect(savedData['role'], 'customer');
      });
}