import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import '../../core/utils/firestore_parser.dart';
import 'address_model.dart';

enum OrderStatus {
  pendingConfirmation('pending_confirmation', 'Chờ xác nhận'),
  confirmed('confirmed', 'Đã xác nhận'),
  preparing('preparing', 'Đang chuẩn bị hàng'),
  shipping('shipping', 'Đang giao'),
  delivered('delivered', 'Đã giao'),
  cancelled('cancelled', 'Đã hủy'),
  refunded('refunded', 'Hoàn tiền');

  const OrderStatus(this.code, this.labelVi);
  final String code;
  final String labelVi;

  static OrderStatus fromCode(String? rawCode) {
    for (final status in OrderStatus.values) {
      if (status.code == rawCode) {
        return status;
      }
    }
    return OrderStatus.pendingConfirmation;
  }
}

class OrderRequestedItem extends Equatable {
  const OrderRequestedItem({
    required this.productId,
    required this.quantity,
  });

  final String productId;
  final int quantity;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'productId': productId,
        'quantity': quantity,
      };

  @override
  List<Object?> get props => [productId, quantity];
}

class OrderItemSnapshot extends Equatable {
  const OrderItemSnapshot({
    required this.productId,
    required this.sku,
    required this.productName,
    required this.brandName,
    required this.thumbnailUrl,
    required this.unitPrice,
    required this.finalUnitPrice,
    required this.quantity,
    required this.lineTotal,
    this.warrantyMonths = 12,
    this.isReviewed = false,
  });

  final String productId;
  final String sku;
  final String productName;
  final String brandName;
  final String thumbnailUrl;
  final int unitPrice;
  final int finalUnitPrice;
  final int quantity;
  final int lineTotal;
  final int warrantyMonths;
  final bool isReviewed;

  factory OrderItemSnapshot.fromMap(Map<String, dynamic> map) {
    final finalPrice = FirestoreParser.parseInt(map['finalUnitPrice']);
    final qty = FirestoreParser.parseInt(map['quantity'], fallback: 1);
    return OrderItemSnapshot(
      productId: FirestoreParser.parseString(map['productId']),
      sku: FirestoreParser.parseString(map['sku']),
      productName: FirestoreParser.parseString(map['productName']),
      brandName: FirestoreParser.parseString(map['brandName']),
      thumbnailUrl: FirestoreParser.parseString(map['thumbnailUrl']),
      unitPrice: FirestoreParser.parseInt(map['unitPrice'], fallback: finalPrice),
      finalUnitPrice: finalPrice,
      quantity: qty,
      lineTotal: FirestoreParser.parseInt(
        map['lineTotal'],
        fallback: finalPrice * qty,
      ),
      warrantyMonths: FirestoreParser.parseInt(
        map['warrantyMonths'],
        fallback: 12,
      ),
      isReviewed: FirestoreParser.parseBool(map['isReviewed']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'productId': productId,
      'sku': sku,
      'productName': productName,
      'brandName': brandName,
      'thumbnailUrl': thumbnailUrl,
      'unitPrice': unitPrice,
      'finalUnitPrice': finalUnitPrice,
      'quantity': quantity,
      'lineTotal': lineTotal,
      'warrantyMonths': warrantyMonths,
      'isReviewed': isReviewed,
    };
  }

  @override
  List<Object?> get props => [
        productId,
        sku,
        productName,
        finalUnitPrice,
        quantity,
        lineTotal,
        isReviewed,
      ];
}

class OrderStatusHistoryEntry extends Equatable {
  const OrderStatusHistoryEntry({
    required this.status,
    required this.note,
    required this.changedBy,
    required this.changedAt,
  });

  final String status;
  final String note;
  final String changedBy;
  final DateTime changedAt;

  factory OrderStatusHistoryEntry.fromMap(Map<String, dynamic> map) {
    return OrderStatusHistoryEntry(
      status: FirestoreParser.parseString(
        map['status'],
        fallback: OrderStatus.pendingConfirmation.code,
      ),
      note: FirestoreParser.parseString(map['note']),
      changedBy: FirestoreParser.parseString(map['changedBy']),
      changedAt: FirestoreParser.parseDateTime(map['changedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'status': status,
      'note': note,
      'changedBy': changedBy,
      'changedAt': Timestamp.fromDate(changedAt),
    };
  }

  @override
  List<Object?> get props => [status, note, changedBy, changedAt];
}

class OrderModel extends Equatable {
  const OrderModel({
    required this.id,
    required this.orderCode,
    required this.idempotencyKey,
    required this.userId,
    required this.userEmail,
    required this.items,
    required this.shippingAddress,
    required this.shippingMethod,
    required this.shippingFee,
    this.couponCode,
    this.discountAmount = 0,
    required this.subtotal,
    required this.totalAmount,
    this.paymentMethod = 'COD',
    this.paymentStatus = 'pending',
    required this.status,
    required this.statusHistory,
    this.customerNote,
    this.cancelReason,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String orderCode;
  final String idempotencyKey;
  final String userId;
  final String userEmail;
  final List<OrderItemSnapshot> items;
  final ShippingAddressModel shippingAddress;
  final String shippingMethod;
  final int shippingFee;
  final String? couponCode;
  final int discountAmount;
  final int subtotal;
  final int totalAmount;
  final String paymentMethod;
  final String paymentStatus;
  final OrderStatus status;
  final List<OrderStatusHistoryEntry> statusHistory;
  final String? customerNote;
  final String? cancelReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get canCustomerCancel =>
      status == OrderStatus.pendingConfirmation ||
      status == OrderStatus.confirmed;

  factory OrderModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};

    final rawItems = data['items'];
    final parsedItems = <OrderItemSnapshot>[];
    if (rawItems is Iterable) {
      for (final item in rawItems) {
        if (item is Map) {
          parsedItems.add(
            OrderItemSnapshot.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final rawAddr = data['shippingAddress'];
    final parsedAddr = rawAddr is Map
        ? ShippingAddressModel.fromMap(Map<String, dynamic>.from(rawAddr))
        : const ShippingAddressModel(
            id: 'snapshot',
            recipientName: '',
            phoneNumber: '',
            province: '',
            district: '',
            ward: '',
            streetAddress: '',
          );

    final rawHistory = data['statusHistory'];
    final parsedHistory = <OrderStatusHistoryEntry>[];
    if (rawHistory is Iterable) {
      for (final h in rawHistory) {
        if (h is Map) {
          parsedHistory.add(
            OrderStatusHistoryEntry.fromMap(Map<String, dynamic>.from(h)),
          );
        }
      }
    }

    return OrderModel(
      id: doc.id,
      orderCode: FirestoreParser.parseString(
        data['orderCode'],
        fallback: doc.id.toUpperCase(),
      ),
      idempotencyKey: FirestoreParser.parseString(data['idempotencyKey']),
      userId: FirestoreParser.parseString(data['userId']),
      userEmail: FirestoreParser.parseString(data['userEmail']),
      items: parsedItems,
      shippingAddress: parsedAddr,
      shippingMethod: FirestoreParser.parseString(
        data['shippingMethod'],
        fallback: 'standard',
      ),
      shippingFee: FirestoreParser.parseInt(data['shippingFee']),
      couponCode: FirestoreParser.parseNullableString(data['couponCode']),
      discountAmount: FirestoreParser.parseInt(data['discountAmount']),
      subtotal: FirestoreParser.parseInt(data['subtotal']),
      totalAmount: FirestoreParser.parseInt(data['totalAmount']),
      paymentMethod: FirestoreParser.parseString(
        data['paymentMethod'],
        fallback: 'COD',
      ),
      paymentStatus: FirestoreParser.parseString(
        data['paymentStatus'],
        fallback: 'pending',
      ),
      status: OrderStatus.fromCode(
        FirestoreParser.parseNullableString(data['status']),
      ),
      statusHistory: parsedHistory,
      customerNote: FirestoreParser.parseNullableString(data['customerNote']),
      cancelReason: FirestoreParser.parseNullableString(data['cancelReason']),
      createdAt: FirestoreParser.parseDateTime(data['createdAt']),
      updatedAt: FirestoreParser.parseDateTime(data['updatedAt']),
    );
  }

  @override
  List<Object?> get props => [
        id,
        orderCode,
        idempotencyKey,
        userId,
        items,
        shippingAddress,
        shippingMethod,
        shippingFee,
        couponCode,
        discountAmount,
        subtotal,
        totalAmount,
        paymentMethod,
        paymentStatus,
        status,
        cancelReason,
      ];
}
