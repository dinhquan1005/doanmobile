import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/firestore_collections.dart';
import '../../core/errors/app_failure.dart';
import '../models/address_model.dart';
import '../models/coupon_model.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';

class OrderRepository {
  OrderRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth firebaseAuth,
    FirebaseFunctions? functions,
  })  : _firestore = firestore,
        _firebaseAuth = firebaseAuth,
        assert(functions != null || true);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  CollectionReference<Map<String, dynamic>> _addressesRef(String userId) {
    return _firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.addressesSubcollection);
  }

  Stream<List<ShippingAddressModel>> watchUserAddresses(String userId) {
    return _addressesRef(userId).snapshots().map((snapshot) {
      final list = snapshot.docs
          .map(ShippingAddressModel.fromFirestore)
          .toList(growable: false);
      final sorted = [...list]..sort((a, b) {
          if (a.isDefault == b.isDefault) return 0;
          return a.isDefault ? -1 : 1;
        });
      return sorted;
    });
  }

  /// Thêm hoặc cập nhật địa chỉ giao hàng
  Future<ShippingAddressModel> saveUserAddress({
    required String userId,
    required ShippingAddressModel address,
  }) async {
    final colRef = _addressesRef(userId);
    final docRef =
        address.id.trim().isEmpty ? colRef.doc() : colRef.doc(address.id);
    final savedAddress = address.copyWith(id: docRef.id);

    final batch = _firestore.batch();
    if (savedAddress.isDefault) {
      final existing = await colRef.get();
      for (final doc in existing.docs) {
        if (doc.id != docRef.id && doc.data()['isDefault'] == true) {
          batch.update(doc.reference, {'isDefault': false});
        }
      }
    }
    batch.set(docRef, savedAddress.toMap());
    await batch.commit();
    return savedAddress;
  }

  /// Xóa địa chỉ giao hàng
  Future<void> deleteUserAddress({
    required String userId,
    required String addressId,
  }) async {
    await _addressesRef(userId).doc(addressId).delete();
  }

  /// [VẤN ĐÁP] Điểm bắt đầu quy trình Đặt hàng từ phía người dùng
  /// - Kiểm tra trạng thái đăng nhập của người dùng.
  /// - Kiểm tra danh sách sản phẩm yêu cầu (`requestedItems`) không được rỗng.
  /// - Chuyển sang thực thi Giao dịch nguyên tử `_executeAtomicOrderTransaction`.
  Future<OrderModel> placeOrder({
    required String idempotencyKey,
    required List<OrderRequestedItem> requestedItems,
    required ShippingAddressModel shippingAddress,
    required String shippingMethod,
    required String paymentMethod,
    String? couponCode,
    String? customerNote,
  }) async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      throw const AuthFailure(
        message: 'Bạn cần đăng nhập để thực hiện đặt hàng.',
      );
    }

    if (requestedItems.isEmpty) {
      throw const ValidationFailure(
        message: 'Danh sách sản phẩm đặt mua đang trống.',
      );
    }

    return _executeAtomicOrderTransaction(
      userId: currentUser.uid,
      userEmail: currentUser.email ?? '',
      idempotencyKey: idempotencyKey.trim(),
      requestedItems: requestedItems,
      shippingAddress: shippingAddress,
      shippingMethod: shippingMethod,
      paymentMethod: paymentMethod,
      couponCode: couponCode,
      customerNote: customerNote,
    );
  }

  /// [VẤN ĐÁP] Giao dịch đặt hàng nguyên tử (Atomic Order Transaction)
  /// Đây là hàm quan trọng nhất trong toàn bộ hệ thống bán hàng:
  /// 1. [CHỐNG TẠO ĐƠN TRÙNG]: Kiểm tra document `order_idempotency/{idempotencyKey}`. Nếu mạng chập chờn hoặc người dùng bấm 2 lần, hàm trả về đơn hàng đã tạo trước đó thay vì trừ tiền 2 lần.
  /// 2. [TÍNH LẠI GIÁ BÁN]: Tuyệt đối KHÔNG tin giá tiền từ client gửi lên. Đọc trực tiếp giá từ Firestore collection `products` để tính lại tổng tiền (`subtotal`).
  /// 3. [KIỂM TRA TỒN KHO & CHỐNG RACE CONDITION]: Sử dụng Firestore Transaction (khóa lạc quan). Nếu `availableStock < req.quantity`, lập tức ném ngoại lệ `InsufficientStockFailure` và ROLLBACK toàn bộ.
  /// 4. [XÁC MINH VOUCHER]: Kiểm tra mã giảm giá còn hiệu lực, số lượt sử dụng và điều kiện đơn tối thiểu.
  /// 5. [LƯU SNAPSHOT SẢN PHẨM]: Chụp ảnh dữ liệu (Snapshot) tên, giá, ảnh, bảo hành tại thời điểm mua để nếu sau này giá sản phẩm đổi thì đơn hàng cũ vẫn giữ nguyên giá lúc mua.
  /// 6. [TRỪ TỒN KHO & GHI LOG]: Giảm `stockQuantity`, tăng `soldCount`, tăng `usedCount` của voucher và ghi log vào `inventory_transactions`.
  Future<OrderModel> _executeAtomicOrderTransaction({
    required String userId,
    required String userEmail,
    required String idempotencyKey,
    required List<OrderRequestedItem> requestedItems,
    required ShippingAddressModel shippingAddress,
    required String shippingMethod,
    required String paymentMethod,
    String? couponCode,
    String? customerNote,
  }) async {
    final idemRef = _firestore
        .collection(FirestoreCollections.orderIdempotency)
        .doc(idempotencyKey);

    final createdOrderId = await _firestore.runTransaction<String>(
      (transaction) async {
        // 1. Kiểm tra Idempotency chống tạo đơn trùng
        final idemSnap = await transaction.get(idemRef);
        if (idemSnap.exists) {
          final existingOrderId = idemSnap.data()?['orderId'] as String?;
          if (existingOrderId != null && existingOrderId.isNotEmpty) {
            return existingOrderId;
          }
        }

        // 2. Đọc toàn bộ sản phẩm từ Firestore để kiểm tra tồn kho và giá mới nhất
        final productDocs =
            <DocumentSnapshot<Map<String, dynamic>>>[];
        for (final req in requestedItems) {
          final prodRef = _firestore
              .collection(FirestoreCollections.products)
              .doc(req.productId);
          final prodSnap = await transaction.get(prodRef);
          productDocs.add(prodSnap);
        }

        CouponModel? validatedCoupon;
        DocumentReference<Map<String, dynamic>>? couponRef;
        final cleanCoupon = couponCode?.trim().toUpperCase() ?? '';
        if (cleanCoupon.isNotEmpty) {
          couponRef = _firestore
              .collection(FirestoreCollections.coupons)
              .doc(cleanCoupon);
          final couponSnap = await transaction.get(couponRef);
          if (!couponSnap.exists) {
            throw ValidationFailure(
              message: 'Mã giảm giá "$cleanCoupon" không tồn tại.',
            );
          }
          validatedCoupon = CouponModel.fromFirestore(couponSnap);
        }

        final now = DateTime.now().toUtc();
        int subtotal = 0;
        final itemSnapshots = <OrderItemSnapshot>[];
        final stockMutations = <({
          DocumentReference<Map<String, dynamic>> ref,
          ProductModel product,
          int requestedQty,
          int newStock,
          int newAvailable,
          int newSold,
        })>[];

        for (var i = 0; i < requestedItems.length; i++) {
          final req = requestedItems[i];
          final snap = productDocs[i];
          if (!snap.exists) {
            throw NotFoundFailure(
              message: 'Sản phẩm (${req.productId}) không tồn tại.',
            );
          }
          final product = ProductModel.fromFirestore(snap);
          if (!product.isActive || product.isDeleted) {
            throw ValidationFailure(
              message: 'Sản phẩm "${product.name}" đã ngừng kinh doanh.',
            );
          }
          if (product.availableStock < req.quantity) {
            throw InsufficientStockFailure(
              productName: product.name,
              availableStock: product.availableStock,
            );
          }

          final unitPrice = product.price;
          final finalUnitPrice = product.effectivePrice;
          final lineTotal = finalUnitPrice * req.quantity;
          subtotal += lineTotal;

          itemSnapshots.add(
            OrderItemSnapshot(
              productId: product.id,
              sku: product.sku,
              productName: product.name,
              brandName: product.brandName,
              thumbnailUrl: product.thumbnailUrl,
              unitPrice: unitPrice,
              finalUnitPrice: finalUnitPrice,
              quantity: req.quantity,
              lineTotal: lineTotal,
              warrantyMonths: product.warrantyMonths,
            ),
          );

          final newStock = product.stockQuantity - req.quantity;
          final newAvailable =
              (newStock - product.reservedQuantity).clamp(0, 999999);
          final newSold = product.soldCount + req.quantity;

          stockMutations.add((
            ref: snap.reference,
            product: product,
            requestedQty: req.quantity,
            newStock: newStock,
            newAvailable: newAvailable,
            newSold: newSold,
          ));
        }

        // 3. Kiểm tra và tính giảm giá
        int discountAmount = 0;
        String? finalCouponCode;
        if (validatedCoupon != null) {
          if (!validatedCoupon.isCurrentlyValid(now)) {
            throw ValidationFailure(
              message:
                  'Mã giảm giá "${validatedCoupon.code}" đã hết hạn hoặc hết lượt dùng.',
            );
          }
          if (subtotal < validatedCoupon.minOrderAmount) {
            throw ValidationFailure(
              message:
                  'Đơn hàng cần đạt tối thiểu ${validatedCoupon.minOrderAmount} ₫ để áp dụng mã ${validatedCoupon.code}.',
            );
          }
          if (validatedCoupon.discountType == 'percentage') {
            final pct = validatedCoupon.discountValue.clamp(0, 100);
            discountAmount = (subtotal * pct) ~/ 100;
            if (validatedCoupon.maxDiscountAmount != null &&
                validatedCoupon.maxDiscountAmount! > 0 &&
                discountAmount > validatedCoupon.maxDiscountAmount!) {
              discountAmount = validatedCoupon.maxDiscountAmount!;
            }
          } else {
            discountAmount = validatedCoupon.discountValue;
          }
          discountAmount = discountAmount.clamp(0, subtotal);
          finalCouponCode = validatedCoupon.code;
        }

        // 4. Tính phí vận chuyển và tổng tiền cuối cùng
        final afterDiscount = subtotal - discountAmount;
        final int shippingFee;
        if (shippingMethod == 'express') {
          shippingFee = AppConstants.defaultExpressShippingFee;
        } else {
          shippingFee =
              afterDiscount >= AppConstants.defaultFreeShippingThreshold
                  ? 0
                  : AppConstants.defaultStandardShippingFee;
        }
        final totalAmount =
            (afterDiscount + shippingFee).clamp(0, 999999999);

        final orderRef =
            _firestore.collection(FirestoreCollections.orders).doc();
        final dateStr =
            '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
        final suffix = orderRef.id.substring(0, 5).toUpperCase();
        final orderCode = 'ORD-$dateStr-$suffix';

        // 5. Ghi trừ tồn kho và lưu log biến động kho
        for (final mut in stockMutations) {
          transaction.update(mut.ref, {
            'stockQuantity': mut.newStock,
            'availableStock': mut.newAvailable,
            'inStock': mut.newAvailable > 0,
            'soldCount': mut.newSold,
            'updatedAt': Timestamp.fromDate(now),
          });

          final txRef = _firestore
              .collection(FirestoreCollections.inventoryTransactions)
              .doc();
          transaction.set(txRef, {
            'id': txRef.id,
            'productId': mut.product.id,
            'sku': mut.product.sku,
            'orderId': orderRef.id,
            'type': 'commit_deduct',
            'quantityChange': -mut.requestedQty,
            'previousStock': mut.product.stockQuantity,
            'newStock': mut.newStock,
            'reason': 'Trừ kho cho đơn hàng $orderCode',
            'performedBy': userId,
            'createdAt': Timestamp.fromDate(now),
          });
        }

        if (couponRef != null && validatedCoupon != null) {
          transaction.update(couponRef, {
            'usedCount': validatedCoupon.usedCount + 1,
          });
        }

        transaction.set(orderRef, {
          'id': orderRef.id,
          'orderCode': orderCode,
          'idempotencyKey': idempotencyKey,
          'userId': userId,
          'userEmail': userEmail,
          'items': itemSnapshots.map((e) => e.toMap()).toList(growable: false),
          'shippingAddress': shippingAddress.toMap(),
          'shippingMethod': shippingMethod,
          'shippingFee': shippingFee,
          'couponCode': finalCouponCode,
          'discountAmount': discountAmount,
          'subtotal': subtotal,
          'totalAmount': totalAmount,
          'paymentMethod': paymentMethod,
          'paymentStatus': 'pending',
          'status': OrderStatus.pendingConfirmation.code,
          'statusHistory': [
            OrderStatusHistoryEntry(
              status: OrderStatus.pendingConfirmation.code,
              note: 'Đơn hàng đã được tạo và xác thực tồn kho thành công.',
              changedBy: userId,
              changedAt: now,
            ).toMap(),
          ],
          'customerNote':
              customerNote?.trim().isNotEmpty == true ? customerNote!.trim() : null,
          'cancelReason': null,
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        });

        transaction.set(idemRef, {
          'idempotencyKey': idempotencyKey,
          'orderId': orderRef.id,
          'orderCode': orderCode,
          'userId': userId,
          'totalAmount': totalAmount,
          'createdAt': Timestamp.fromDate(now),
        });

        return orderRef.id;
      },
    );

    final createdOrder = await fetchOrderById(createdOrderId);
    if (createdOrder == null) {
      throw const ServerFailure(
        message: 'Đã tạo đơn hàng nhưng không thể đọc lại chi tiết đơn.',
      );
    }
    return createdOrder;
  }

  Future<OrderModel?> fetchOrderById(String orderId) async {
    final doc = await _firestore
        .collection(FirestoreCollections.orders)
        .doc(orderId)
        .get();
    if (!doc.exists) {
      return null;
    }
    return OrderModel.fromFirestore(doc);
  }

  Stream<OrderModel?> watchOrderById(String orderId) {
    return _firestore
        .collection(FirestoreCollections.orders)
        .doc(orderId)
        .snapshots()
        .map((doc) => doc.exists ? OrderModel.fromFirestore(doc) : null);
  }

  Stream<List<OrderModel>> watchUserOrders(String userId) {
    return _firestore
        .collection(FirestoreCollections.orders)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final orders =
          snapshot.docs.map(OrderModel.fromFirestore).toList(growable: false);
      final sorted = [...orders]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return sorted;
    });
  }

  Future<void> cancelOrder({
    required String orderId,
    required String cancelReason,
  }) async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      throw const AuthFailure(message: 'Vui lòng đăng nhập.');
    }
    await cancelOrderAndRestoreStock(
      orderId: orderId,
      userId: currentUser.uid,
      reason: cancelReason,
      isAdminOrStaff: false,
    );
  }

  /// [VẤN ĐÁP] Hủy đơn hàng và tự động Hoàn trả tồn kho (Stock Rollback)
  /// - Kiểm tra quyền: Chỉ chủ sở hữu đơn hàng hoặc Quản trị viên mới có quyền hủy đơn.
  /// - Kiểm tra trạng thái: Chỉ đơn hàng đang ở trạng thái `pending` (Chờ xác nhận) mới được phép hủy.
  /// - Hoàn trả tồn kho: Thực thi trong Transaction để cộng lại `stockQuantity` và `availableStock`, trừ `soldCount`.
  /// - Ghi nhật ký: Ghi log biến động kho vào `inventory_transactions` với type `restock_cancel` để đối soát.
  Future<void> cancelOrderAndRestoreStock({
    required String orderId,
    required String userId,
    required String reason,
    bool isAdminOrStaff = false,
  }) async {
    final orderRef =
        _firestore.collection(FirestoreCollections.orders).doc(orderId);

    await _firestore.runTransaction((transaction) async {
      final orderSnap = await transaction.get(orderRef);
      if (!orderSnap.exists) {
        throw const NotFoundFailure(message: 'Không tìm thấy đơn hàng.');
      }

      final order = OrderModel.fromFirestore(orderSnap);
      if (order.userId != userId && !isAdminOrStaff) {
        throw const PermissionDeniedFailure();
      }

      if (!order.canCustomerCancel && !isAdminOrStaff) {
        throw const ValidationFailure(
          message:
              'Đơn hàng đã chuyển sang khâu chuẩn bị/vận chuyển nên không thể hủy.',
        );
      }

      final productSnaps = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final item in order.items) {
        final pRef = _firestore
            .collection(FirestoreCollections.products)
            .doc(item.productId);
        productSnaps.add(await transaction.get(pRef));
      }

      final now = DateTime.now().toUtc();

      for (var i = 0; i < order.items.length; i++) {
        final item = order.items[i];
        final pSnap = productSnaps[i];
        if (pSnap.exists) {
          final product = ProductModel.fromFirestore(pSnap);
          final restoredStock = product.stockQuantity + item.quantity;
          final restoredAvailable =
              (restoredStock - product.reservedQuantity).clamp(0, 999999);
          final updatedSold =
              (product.soldCount - item.quantity).clamp(0, 999999);

          transaction.update(pSnap.reference, {
            'stockQuantity': restoredStock,
            'availableStock': restoredAvailable,
            'inStock': restoredAvailable > 0,
            'soldCount': updatedSold,
            'updatedAt': Timestamp.fromDate(now),
          });

          final txRef = _firestore
              .collection(FirestoreCollections.inventoryTransactions)
              .doc();
          transaction.set(txRef, {
            'id': txRef.id,
            'productId': product.id,
            'sku': product.sku,
            'orderId': order.id,
            'type': 'release_reserve',
            'quantityChange': item.quantity,
            'previousStock': product.stockQuantity,
            'newStock': restoredStock,
            'reason': 'Hoàn kho do hủy đơn ${order.orderCode}: $reason',
            'performedBy': userId,
            'createdAt': Timestamp.fromDate(now),
          });
        }
      }

      final updatedHistory = <Map<String, dynamic>>[
        ...order.statusHistory.map((e) => e.toMap()),
        OrderStatusHistoryEntry(
          status: OrderStatus.cancelled.code,
          note: 'Đã hủy đơn hàng. Lý do: $reason',
          changedBy: userId,
          changedAt: now,
        ).toMap(),
      ];

      transaction.update(orderRef, {
        'status': OrderStatus.cancelled.code,
        'cancelReason': reason.trim(),
        'statusHistory': updatedHistory,
        'updatedAt': Timestamp.fromDate(now),
      });
    });
  }
}

