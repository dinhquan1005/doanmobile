import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/firestore_collections.dart';
import '../../core/errors/app_failure.dart';
import '../models/cart_model.dart';
import '../models/coupon_model.dart';
import '../models/product_model.dart';

class CartRepository {
  CartRepository({
    required FirebaseFirestore firestore,
    SharedPreferences? sharedPreferences,
  })  : _firestore = firestore,
        _prefs = sharedPreferences;

  final FirebaseFirestore _firestore;
  final SharedPreferences? _prefs;

  static const String _prefGuestCouponKey = 'pref_guest_cart_coupon';

  DocumentReference<Map<String, dynamic>> _userCartDoc(String userId) {
    return _firestore.collection(FirestoreCollections.carts).doc(userId);
  }

  CartDocumentModel loadGuestCart() {
    final prefs = _prefs;
    final now = DateTime.now().toUtc();
    if (prefs == null) {
      return CartDocumentModel(userId: 'guest', updatedAt: now);
    }
    final rawJson = prefs.getString(AppConstants.prefGuestCartKey);
    final couponCode = prefs.getString(_prefGuestCouponKey);
    if (rawJson == null || rawJson.isEmpty) {
      return CartDocumentModel(
        userId: 'guest',
        appliedCouponCode: couponCode,
        updatedAt: now,
      );
    }
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is List) {
        final entries = decoded
            .whereType<Map<String, dynamic>>()
            .map(CartItemEntry.fromMap)
            .where((e) => e.productId.isNotEmpty)
            .toList(growable: false);
        return CartDocumentModel(
          userId: 'guest',
          items: entries,
          appliedCouponCode: couponCode,
          updatedAt: now,
        );
      }
    } catch (_) {
      // Nếu dữ liệu cục bộ bị hỏng, trả về giỏ hàng trống an toàn
    }
    return CartDocumentModel(
      userId: 'guest',
      appliedCouponCode: couponCode,
      updatedAt: now,
    );
  }

  Future<void> saveGuestCart({
    required List<CartItemEntry> items,
    required String? appliedCouponCode,
  }) async {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    final encoded = jsonEncode(
      items.map((e) => e.toJsonMap()).toList(growable: false),
    );
    await prefs.setString(AppConstants.prefGuestCartKey, encoded);
    if (appliedCouponCode != null && appliedCouponCode.trim().isNotEmpty) {
      await prefs.setString(
        _prefGuestCouponKey,
        appliedCouponCode.trim().toUpperCase(),
      );
    } else {
      await prefs.remove(_prefGuestCouponKey);
    }
  }

  Future<void> clearGuestCart() async {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    await prefs.remove(AppConstants.prefGuestCartKey);
    await prefs.remove(_prefGuestCouponKey);
  }

  /// Lấy document giỏ hàng trên Cloud Firestore của người dùng đã đăng nhập
  Future<CartDocumentModel> fetchUserCart(String userId) async {
    final snapshot = await _userCartDoc(userId).get();
    if (!snapshot.exists) {
      return CartDocumentModel(
        userId: userId,
        updatedAt: DateTime.now().toUtc(),
      );
    }
    return CartDocumentModel.fromFirestore(snapshot);
  }

  /// Lắng nghe thay đổi giỏ hàng thời gian thực giữa các thiết bị
  Stream<CartDocumentModel> watchUserCart(String userId) {
    return _userCartDoc(userId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return CartDocumentModel(
          userId: userId,
          updatedAt: DateTime.now().toUtc(),
        );
      }
      return CartDocumentModel.fromFirestore(snapshot);
    });
  }

  Future<void> saveUserCart({
    required String userId,
    required List<CartItemEntry> items,
    required String? appliedCouponCode,
  }) async {
    final cartModel = CartDocumentModel(
      userId: userId,
      items: items,
      appliedCouponCode: appliedCouponCode,
      updatedAt: DateTime.now().toUtc(),
    );
    await _userCartDoc(userId).set(cartModel.toFirestoreMap());
  }

  Future<CartDocumentModel> mergeGuestCartIntoUserCart(String userId) async {
    final guestCart = loadGuestCart();
    final remoteCart = await fetchUserCart(userId);

    if (guestCart.items.isEmpty && guestCart.appliedCouponCode == null) {
      return remoteCart;
    }

    final mergedMap = <String, CartItemEntry>{
      for (final item in remoteCart.items) item.productId: item,
    };

    for (final guestItem in guestCart.items) {
      final existing = mergedMap[guestItem.productId];
      if (existing != null) {
        mergedMap[guestItem.productId] = existing.copyWith(
          quantity: existing.quantity + guestItem.quantity,
          isSelected: existing.isSelected || guestItem.isSelected,
        );
      } else {
        mergedMap[guestItem.productId] = guestItem;
      }
    }

    final mergedItems = mergedMap.values.toList(growable: false);
    final mergedCoupon =
        remoteCart.appliedCouponCode ?? guestCart.appliedCouponCode;

    await saveUserCart(
      userId: userId,
      items: mergedItems,
      appliedCouponCode: mergedCoupon,
    );
    await clearGuestCart();

    return CartDocumentModel(
      userId: userId,
      items: mergedItems,
      appliedCouponCode: mergedCoupon,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  /// Truy vấn thông tin sản phẩm mới nhất từ Firestore (hỗ trợ chia batch 10 ID theo giới hạn whereIn)
  Future<Map<String, ProductModel>> fetchLatestProductsMap(
      List<String> productIds,
      ) async {
    final uniqueIds = productIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (uniqueIds.isEmpty) {
      return const <String, ProductModel>{};
    }

    final result = <String, ProductModel>{};
    for (var i = 0; i < uniqueIds.length; i += 10) {
      final chunk = uniqueIds.sublist(
        i,
        i + 10 > uniqueIds.length ? uniqueIds.length : i + 10,
      );
      final snapshot = await _firestore
          .collection(FirestoreCollections.products)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final doc in snapshot.docs) {
        result[doc.id] = ProductModel.fromFirestore(doc);
      }
    }
    return result;
  }

  Future<List<ResolvedCartItem>> resolveCartItemsWithLatestProducts(
      List<CartItemEntry> entries,
      ) async {
    if (entries.isEmpty) {
      return const <ResolvedCartItem>[];
    }
    final productIds =
    entries.map((e) => e.productId).toList(growable: false);
    final latestProductsMap = await fetchLatestProductsMap(productIds);

    return entries
        .map(
          (entry) => ResolvedCartItem(
        entry: entry,
        product: latestProductsMap[entry.productId],
      ),
    )
        .toList(growable: false);
  }

  Future<CouponModel> validateCoupon({
    required String rawCode,
    required int currentSubtotal,
  }) async {
    final normalizedCode = rawCode.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      throw const ValidationFailure(message: 'Vui lòng nhập mã giảm giá.');
    }

    final doc = await _firestore
        .collection(FirestoreCollections.coupons)
        .doc(normalizedCode)
        .get();

    if (!doc.exists) {
      throw ValidationFailure(
        message: 'Mã giảm giá "$normalizedCode" không tồn tại.',
      );
    }

    final coupon = CouponModel.fromFirestore(doc);
    final now = DateTime.now().toUtc();

    if (!coupon.isActive) {
      throw ValidationFailure(
        message: 'Mã giảm giá "$normalizedCode" đã ngưng áp dụng.',
      );
    }
    if (now.isBefore(coupon.startDate)) {
      throw ValidationFailure(
        message: 'Mã giảm giá "$normalizedCode" chưa đến thời gian mở.',
      );
    }
    if (now.isAfter(coupon.endDate)) {
      throw ValidationFailure(
        message: 'Mã giảm giá "$normalizedCode" đã hết hạn sử dụng.',
      );
    }
    if (coupon.usedCount >= coupon.usageLimit) {
      throw ValidationFailure(
        message: 'Mã giảm giá "$normalizedCode" đã hết lượt sử dụng.',
      );
    }
    if (currentSubtotal < coupon.minOrderAmount) {
      throw ValidationFailure(
        message:
        'Đơn hàng cần đạt tối thiểu ${coupon.minOrderAmount} ₫ để áp dụng mã ${coupon.code}.',
      );
    }

    return coupon;
  }
}