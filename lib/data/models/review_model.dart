import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import '../../core/utils/firestore_parser.dart';

class ReviewModel extends Equatable {
  const ReviewModel({
    required this.id,
    required this.productId,
    required this.orderId,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    required this.rating,
    required this.comment,
    this.imageUrls = const <String>[],
    this.status = 'approved',
    this.adminReply,
    required this.createdAt,
  });

  final String id;
  final String productId;
  final String orderId;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final int rating;
  final String comment;
  final List<String> imageUrls;
  final String status;
  final String? adminReply;
  final DateTime createdAt;

  factory ReviewModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ReviewModel(
      id: doc.id,
      productId: FirestoreParser.parseString(data['productId']),
      orderId: FirestoreParser.parseString(data['orderId']),
      userId: FirestoreParser.parseString(data['userId']),
      userName: FirestoreParser.parseString(
        data['userName'],
        fallback: 'Khách hàng đã mua',
      ),
      userAvatarUrl: FirestoreParser.parseNullableString(data['userAvatarUrl']),
      rating: FirestoreParser.parseInt(data['rating'], fallback: 5).clamp(1, 5),
      comment: FirestoreParser.parseString(data['comment']),
      imageUrls: FirestoreParser.parseStringList(data['imageUrls']),
      status: FirestoreParser.parseString(
        data['status'],
        fallback: 'approved',
      ),
      adminReply: FirestoreParser.parseNullableString(data['adminReply']),
      createdAt: FirestoreParser.parseDateTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return <String, dynamic>{
      'id': id,
      'productId': productId,
      'orderId': orderId,
      'userId': userId,
      'userName': userName,
      'userAvatarUrl': userAvatarUrl,
      'rating': rating,
      'comment': comment,
      'imageUrls': imageUrls,
      'status': status,
      'adminReply': adminReply,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  @override
  List<Object?> get props => [
    id,
    productId,
    orderId,
    userId,
    userName,
    rating,
    comment,
    status,
    adminReply,
    createdAt,
  ];
}