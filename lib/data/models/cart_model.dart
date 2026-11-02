import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/firestore_parser.dart';
import 'coupon_model.dart';
import 'product_model.dart';

class CartItemEntry extends Equatable {
  const CartItemEntry({
    required this.productId,
    required this.quantity,
    this.isSelected = true,
    required this.addedAt,
  });

  final String productId;
  final int quantity;
  final bool isSelected;
  final DateTime addedAt;

  factory CartItemEntry.fromMap(Map<String, dynamic> map) {
    final rawQty = FirestoreParser.parseInt(map['quantity'], fallback: 1);
    return CartItemEntry(
      productId: FirestoreParser.parseString(map['productId']),
      quantity: rawQty < 1 ? 1 : rawQty,
      isSelected: FirestoreParser.parseBool(map['isSelected'], fallback: true),
      addedAt: FirestoreParser.parseDateTime(map['addedAt']),
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return <String, dynamic>{
      'productId': productId,
      'quantity': quantity,
      'isSelected': isSelected,
      'addedAt': Timestamp.fromDate(addedAt),
    };
  }

  Map<String, dynamic> toJsonMap() {
    return <String, dynamic>{
      'productId': productId,
      'quantity': quantity,
      'isSelected': isSelected,
      'addedAt': addedAt.toUtc().toIso8601String(),
    };
  }

  CartItemEntry copyWith({
    int? quantity,
    bool? isSelected,
    DateTime? addedAt,
  }) {
    return CartItemEntry(
      productId: productId,
      quantity: quantity ?? this.quantity,
      isSelected: isSelected ?? this.isSelected,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  List<Object?> get props => [productId, quantity, isSelected, addedAt];
}

class CartDocumentModel extends Equatable {
  const CartDocumentModel({
    required this.userId,
    this.items = const <CartItemEntry>[],
    this.appliedCouponCode,
    required this.updatedAt,
  });

  final String userId;
  final List<CartItemEntry> items;
  final String? appliedCouponCode;
  final DateTime updatedAt;

  factory CartDocumentModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawList = data['items'];
    final parsedItems = <CartItemEntry>[];
    if (rawList is Iterable) {
      for (final raw in rawList) {
        if (raw is Map) {
          final entry = CartItemEntry.fromMap(Map<String, dynamic>.from(raw));
          if (entry.productId.isNotEmpty) {
            parsedItems.add(entry);
          }
        }
      }
    }
    return CartDocumentModel(
      userId: doc.id,
      items: parsedItems,
      appliedCouponCode: FirestoreParser.parseNullableString(
        data['appliedCouponCode'],
      ),
      updatedAt: FirestoreParser.parseDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return <String, dynamic>{
      'userId': userId,
      'items': items.map((e) => e.toFirestoreMap()).toList(growable: false),
      'appliedCouponCode': appliedCouponCode,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  @override
  List<Object?> get props => [userId, items, appliedCouponCode, updatedAt];
}

/// Dòng sản phẩm trong giỏ hàng sau khi đối chiếu giá & tồn kho mới nhất từ Firestore
class ResolvedCartItem extends Equatable {
  const ResolvedCartItem({
    required this.entry,
    required this.product,
  });

  final CartItemEntry entry;
  final ProductModel? product;

  String get productId => entry.productId;
  int get quantity => entry.quantity;
  bool get isSelected => entry.isSelected;

  bool get isProductAvailable =>
      product != null && product!.isActive && !product!.isDeleted;

  int get availableStock => product?.availableStock ?? 0;

  bool get isOutOfStock => !isProductAvailable || availableStock <= 0;

  bool get isExceedingStock =>
      isProductAvailable && availableStock > 0 && quantity > availableStock;

  bool get hasStockIssue => isOutOfStock || isExceedingStock;

  /// Đơn giá mới nhất từ Firestore (VND - kiểu int)
  int get latestUnitPrice => isProductAvailable ? product!.effectivePrice : 0;

  /// Thành tiền của dòng sản phẩm = đơn giá mới nhất * số lượng (VND - kiểu int)
  int get lineSubtotal => latestUnitPrice * quantity;

  String? get stockWarningMessage {
    if (!isProductAvailable) {
      return 'Sản phẩm đã ngừng kinh doanh. Vui lòng xóa khỏi giỏ hàng.';
    }
    if (availableStock <= 0) {
      return 'Sản phẩm tạm hết hàng.';
    }
    if (quantity > availableStock) {
      return 'Chỉ còn $availableStock sản phẩm trong kho (bạn đang chọn $quantity).';
    }
    return null;
  }

  @override
  List<Object?> get props => [entry, product];
}

/// Bản tính tạm tính giỏ hàng bằng số nguyên VND.
/// Lưu ý: Tổng tiền chính thức khi tạo đơn hàng sẽ được kiểm tra và tính lại phía máy chủ.
class CartSummary extends Equatable {
  const CartSummary({
    required this.items,
    this.appliedCoupon,
    this.couponValidationError,
    this.freeShippingThreshold = AppConstants.defaultFreeShippingThreshold,
    this.standardShippingFee = AppConstants.defaultStandardShippingFee,
  });

  final List<ResolvedCartItem> items;
  final CouponModel? appliedCoupon;
  final String? couponValidationError;
  final int freeShippingThreshold;
  final int standardShippingFee;

  int get totalItemCount => items.fold<int>(
    0,
        (int accumulator, ResolvedCartItem item) => accumulator + item.quantity,
  );

  List<ResolvedCartItem> get selectedItems =>
      items.where((item) => item.isSelected).toList(growable: false);

  bool get isAllSelected =>
      items.isNotEmpty && items.every((item) => item.isSelected);

  bool get hasSelectedItemsWithStockIssue =>
      selectedItems.any((item) => item.hasStockIssue);

  bool get canProceedToCheckout =>
      selectedItems.isNotEmpty && !hasSelectedItemsWithStockIssue;

  /// Tạm tính (VND - int) của các sản phẩm được tích chọn
  int get subtotal {
    return selectedItems.fold<int>(
      0,
          (int accumulator, ResolvedCartItem item) =>
      accumulator + item.lineSubtotal,
    );
  }

  /// Số tiền giảm giá từ mã khuyến mãi (VND - int)
  int get discountAmount {
    final coupon = appliedCoupon;
    if (coupon == null || subtotal <= 0) {
      return 0;
    }
    if (subtotal < coupon.minOrderAmount) {
      return 0;
    }
    int rawDiscount = 0;
    if (coupon.discountType == 'percentage') {
      final pct = coupon.discountValue.clamp(0, 100);
      rawDiscount = (subtotal * pct) ~/ 100;
      if (coupon.maxDiscountAmount != null &&
          coupon.maxDiscountAmount! > 0 &&
          rawDiscount > coupon.maxDiscountAmount!) {
        rawDiscount = coupon.maxDiscountAmount!;
      }
    } else {
      rawDiscount = coupon.discountValue;
    }
    if (rawDiscount < 0) {
      return 0;
    }
    return rawDiscount > subtotal ? subtotal : rawDiscount;
  }

  /// Phí giao hàng tiêu chuẩn dự kiến (VND - int)
  int get estimatedShippingFee {
    if (selectedItems.isEmpty || subtotal <= 0) {
      return 0;
    }
    final afterDiscount = subtotal - discountAmount;
    if (afterDiscount >= freeShippingThreshold) {
      return 0;
    }
    return standardShippingFee;
  }

  /// Tổng tiền thanh toán tạm tính (VND - int)
  int get estimatedTotal {
    if (selectedItems.isEmpty || subtotal <= 0) {
      return 0;
    }
    final total = subtotal - discountAmount + estimatedShippingFee;
    return total < 0 ? 0 : total;
  }

  /// Dữ liệu đầu vào gửi lên máy chủ khi tạo đơn hàng (KHÔNG gửi giá tiền do client tính)
  List<Map<String, dynamic>> toServerCheckoutPayload() {
    return selectedItems
        .map(
          (item) => <String, dynamic>{
        'productId': item.productId,
        'quantity': item.quantity,
      },
    )
        .toList(growable: false);
  }

  @override
  List<Object?> get props => [
    items,
    appliedCoupon,
    couponValidationError,
    freeShippingThreshold,
    standardShippingFee,
  ];
}