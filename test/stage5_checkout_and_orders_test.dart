import 'package:electronic_store/core/constants/firestore_collections.dart';
import 'package:electronic_store/core/errors/app_failure.dart';
import 'package:electronic_store/data/datasources/catalog_seed_service.dart';
import 'package:electronic_store/data/models/address_model.dart';
import 'package:electronic_store/data/models/order_model.dart';
import 'package:electronic_store/data/repositories/order_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi_VN', null);
  });

  const sampleAddress = ShippingAddressModel(
    id: 'addr_1',
    recipientName: 'Trương Đình Quân',
    phoneNumber: '0912345678',
    province: 'TP. Hồ Chí Minh',
    district: 'Quận Bình Thạnh',
    ward: 'Phường 25',
    streetAddress: '475A Điện Biên Phủ',
    isDefault: true,
  );

  group('Stage 5 — Order Transaction, Idempotency, Stock & Cancellation Tests',
      () {
    test(
        'Tạo đơn hàng COD lưu Snapshot, tính lại giá + mã giảm giá phía server, trừ kho và chống tạo đơn trùng (Idempotency)',
        () async {
      final fakeFirestore = FakeFirebaseFirestore();
      await CatalogSeedService(fakeFirestore).seedInitialCatalogToFirestore();

      final mockUser = MockUser(
        uid: 'user_quan_1850',
        email: 'quan@electronicstore.vn',
        displayName: 'Trương Đình Quân',
      );
      final mockAuth = MockFirebaseAuth(signedIn: true, mockUser: mockUser);

      final orderRepo = OrderRepository(
        firestore: fakeFirestore,
        firebaseAuth: mockAuth,
      );

      final order = await orderRepo.placeOrder(
        idempotencyKey: 'idem-key-unique-001',
        requestedItems: const [
          OrderRequestedItem(productId: 'prod-cpu-i5-13400f', quantity: 2),
        ],
        shippingAddress: sampleAddress,
        shippingMethod: 'standard',
        paymentMethod: 'COD',
        couponCode: 'LINHKIEN150K',
        customerNote: 'Giao giờ hành chính giúp mình',
      );

      expect(order.subtotal, 9380000);
      expect(order.discountAmount, 150000);
      expect(order.shippingFee, 0);
      expect(order.totalAmount, 9230000);
      expect(order.status, OrderStatus.pendingConfirmation);
      expect(order.shippingAddress.recipientName, 'Trương Đình Quân');
      expect(order.items.first.sku, 'CPU-INTEL-I5-13400F');

      final prodAfter = await fakeFirestore
          .collection(FirestoreCollections.products)
          .doc('prod-cpu-i5-13400f')
          .get();
      expect(prodAfter.data()!['stockQuantity'], 33);
      expect(prodAfter.data()!['availableStock'], 33);

      final duplicateOrder = await orderRepo.placeOrder(
        idempotencyKey: 'idem-key-unique-001',
        requestedItems: const [
          OrderRequestedItem(productId: 'prod-cpu-i5-13400f', quantity: 2),
        ],
        shippingAddress: sampleAddress,
        shippingMethod: 'standard',
        paymentMethod: 'COD',
        couponCode: 'LINHKIEN150K',
      );

      expect(duplicateOrder.id, order.id);
      final allOrders =
          await fakeFirestore.collection(FirestoreCollections.orders).get();
      expect(allOrders.docs.length, 1);

      final prodAfterDuplicate = await fakeFirestore
          .collection(FirestoreCollections.products)
          .doc('prod-cpu-i5-13400f')
          .get();
      expect(prodAfterDuplicate.data()!['stockQuantity'], 33);
    });

    test('Chặn đặt hàng khi số lượng vượt quá tồn kho khả dụng', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      await CatalogSeedService(fakeFirestore).seedInitialCatalogToFirestore();

      final mockUser = MockUser(uid: 'user_quan_1850', email: 'quan@test.vn');
      final mockAuth = MockFirebaseAuth(signedIn: true, mockUser: mockUser);
      final orderRepo = OrderRepository(
        firestore: fakeFirestore,
        firebaseAuth: mockAuth,
      );

      await expectLater(
        () => orderRepo.placeOrder(
          idempotencyKey: 'idem-key-overstock-002',
          requestedItems: const [
            OrderRequestedItem(
              productId: 'prod-monitor-asus-tuf-vg279q3a',
              quantity: 20,
            ),
          ],
          shippingAddress: sampleAddress,
          shippingMethod: 'standard',
          paymentMethod: 'COD',
        ),
        throwsA(isA<InsufficientStockFailure>()),
      );

      final monitorSnap = await fakeFirestore
          .collection(FirestoreCollections.products)
          .doc('prod-monitor-asus-tuf-vg279q3a')
          .get();
      expect(monitorSnap.data()!['stockQuantity'], 16);
    });

    test(
        'Hủy đơn hàng hoàn trả tồn kho chính xác và lưu log inventory_transactions',
        () async {
      final fakeFirestore = FakeFirebaseFirestore();
      await CatalogSeedService(fakeFirestore).seedInitialCatalogToFirestore();

      final mockUser = MockUser(uid: 'user_quan_1850', email: 'quan@test.vn');
      final mockAuth = MockFirebaseAuth(signedIn: true, mockUser: mockUser);
      final orderRepo = OrderRepository(
        firestore: fakeFirestore,
        firebaseAuth: mockAuth,
      );

      final createdOrder = await orderRepo.placeOrder(
        idempotencyKey: 'idem-key-cancel-003',
        requestedItems: const [
          OrderRequestedItem(
            productId: 'prod-diy-arduino-uno-r4-wifi',
            quantity: 3,
          ),
        ],
        shippingAddress: sampleAddress,
        shippingMethod: 'express',
        paymentMethod: 'COD',
      );

      var arduinoSnap = await fakeFirestore
          .collection(FirestoreCollections.products)
          .doc('prod-diy-arduino-uno-r4-wifi')
          .get();
      expect(arduinoSnap.data()!['stockQuantity'], 77);

      await orderRepo.cancelOrder(
        orderId: createdOrder.id,
        cancelReason: 'Đổi sang mua kit cảm biến kèm mạch',
      );

      final cancelledOrder = await orderRepo.fetchOrderById(createdOrder.id);
      expect(cancelledOrder?.status, OrderStatus.cancelled);
      expect(
        cancelledOrder?.cancelReason,
        'Đổi sang mua kit cảm biến kèm mạch',
      );

      arduinoSnap = await fakeFirestore
          .collection(FirestoreCollections.products)
          .doc('prod-diy-arduino-uno-r4-wifi')
          .get();
      expect(arduinoSnap.data()!['stockQuantity'], 80);
      expect(arduinoSnap.data()!['availableStock'], 80);

      final invLogs = await fakeFirestore
          .collection(FirestoreCollections.inventoryTransactions)
          .where('orderId', isEqualTo: createdOrder.id)
          .get();
      expect(invLogs.docs.length, 2);
    });
  });
}
