import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import '../../core/utils/firestore_parser.dart';

class BannerModel extends Equatable {
  const BannerModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.targetType = 'none',
    this.targetId,
    this.sortOrder = 0,
    this.isActive = true,
    this.startDate,
    this.endDate,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String targetType;
  final String? targetId;
  final int sortOrder;
  final bool isActive;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime createdAt;

  factory BannerModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return BannerModel(
      id: doc.id,
      title: FirestoreParser.parseString(data['title']),
      subtitle: FirestoreParser.parseString(data['subtitle']),
      imageUrl: FirestoreParser.parseString(data['imageUrl']),
      targetType: FirestoreParser.parseString(
        data['targetType'],
        fallback: 'none',
      ),
      targetId: FirestoreParser.parseNullableString(data['targetId']),
      sortOrder: FirestoreParser.parseInt(data['sortOrder']),
      isActive: FirestoreParser.parseBool(data['isActive'], fallback: true),
      startDate: data['startDate'] != null
          ? FirestoreParser.parseDateTime(data['startDate'])
          : null,
      endDate: data['endDate'] != null
          ? FirestoreParser.parseDateTime(data['endDate'])
          : null,
      createdAt: FirestoreParser.parseDateTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'imageUrl': imageUrl,
      'targetType': targetType,
      'targetId': targetId,
      'sortOrder': sortOrder,
      'isActive': isActive,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  @override
  List<Object?> get props => [
    id,
    title,
    subtitle,
    imageUrl,
    targetType,
    targetId,
    sortOrder,
    isActive,
  ];
}