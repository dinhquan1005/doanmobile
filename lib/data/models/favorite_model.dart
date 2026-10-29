import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import '../../core/utils/firestore_parser.dart';

class FavoriteModel extends Equatable {
  const FavoriteModel({
    required this.id,
    required this.userId,
    required this.productId,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String productId;
  final DateTime createdAt;

  static String buildId({
    required String userId,
    required String productId,
  }) =>
      '${userId}_$productId';

  factory FavoriteModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return FavoriteModel(
      id: doc.id,
      userId: FirestoreParser.parseString(data['userId']),
      productId: FirestoreParser.parseString(data['productId']),
      createdAt: FirestoreParser.parseDateTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return <String, dynamic>{
      'id': id,
      'userId': userId,
      'productId': productId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  @override
  List<Object?> get props => [id, userId, productId, createdAt];
}