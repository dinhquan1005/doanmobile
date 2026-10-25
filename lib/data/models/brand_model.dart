import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import '../../core/utils/firestore_parser.dart';

class BrandModel extends Equatable {
  const BrandModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.logoUrl,
    this.originCountry = '',
    this.isActive = true,
    this.sortOrder = 0,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String slug;
  final String logoUrl;
  final String originCountry;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;

  factory BrandModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return BrandModel(
      id: doc.id,
      name: FirestoreParser.parseString(data['name'], fallback: 'Thương hiệu'),
      slug: FirestoreParser.parseString(data['slug'], fallback: doc.id),
      logoUrl: FirestoreParser.parseString(data['logoUrl']),
      originCountry: FirestoreParser.parseString(data['originCountry']),
      isActive: FirestoreParser.parseBool(data['isActive'], fallback: true),
      sortOrder: FirestoreParser.parseInt(data['sortOrder']),
      createdAt: FirestoreParser.parseDateTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'slug': slug,
      'logoUrl': logoUrl,
      'originCountry': originCountry,
      'isActive': isActive,
      'sortOrder': sortOrder,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  @override
  List<Object?> get props => [
    id,
    name,
    slug,
    logoUrl,
    originCountry,
    isActive,
    sortOrder,
  ];
}