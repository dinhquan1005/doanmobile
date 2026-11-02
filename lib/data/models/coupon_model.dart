import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import '../../core/utils/firestore_parser.dart';

class CouponModel extends Equatable {
  const CouponModel({
    required this.code,
    required this.title,
    required this.description,
    required this.discountType,
    required this.discountValue,
    this.maxDiscountAmount,
    this.minOrderAmount = 0,
    this.usageLimit = 100,
    this.usedCount = 0,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
  });

  final String code;
  final String title;
  final String description;
  final String discountType; // 'fixed' | 'percentage'
  final int discountValue;
  final int? maxDiscountAmount;
  final int minOrderAmount;
  final int usageLimit;
  final int usedCount;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;

  bool isCurrentlyValid(DateTime now) {
    return isActive &&
        usedCount < usageLimit &&
        !now.isBefore(startDate) &&
        !now.isAfter(endDate);
  }

  factory CouponModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return CouponModel(
      code: FirestoreParser.parseString(
        data['code'],
        fallback: doc.id,
      ).toUpperCase(),
      title: FirestoreParser.parseString(data['title']),
      description: FirestoreParser.parseString(data['description']),
      discountType: FirestoreParser.parseString(
        data['discountType'],
        fallback: 'fixed',
      ),
      discountValue: FirestoreParser.parseInt(data['discountValue']),
      maxDiscountAmount: data['maxDiscountAmount'] != null
          ? FirestoreParser.parseInt(data['maxDiscountAmount'])
          : null,
      minOrderAmount: FirestoreParser.parseInt(data['minOrderAmount']),
      usageLimit: FirestoreParser.parseInt(data['usageLimit'], fallback: 100),
      usedCount: FirestoreParser.parseInt(data['usedCount']),
      startDate: FirestoreParser.parseDateTime(data['startDate']),
      endDate: FirestoreParser.parseDateTime(data['endDate']),
      isActive: FirestoreParser.parseBool(data['isActive'], fallback: true),
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return <String, dynamic>{
      'code': code,
      'title': title,
      'description': description,
      'discountType': discountType,
      'discountValue': discountValue,
      'maxDiscountAmount': maxDiscountAmount,
      'minOrderAmount': minOrderAmount,
      'usageLimit': usageLimit,
      'usedCount': usedCount,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'isActive': isActive,
    };
  }

  @override
  List<Object?> get props => [
    code,
    title,
    description,
    discountType,
    discountValue,
    maxDiscountAmount,
    minOrderAmount,
    usageLimit,
    usedCount,
    startDate,
    endDate,
    isActive,
  ];
}