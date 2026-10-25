import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import '../../core/utils/firestore_parser.dart';

class CategoryModel extends Equatable {
  const CategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.parentId,
    required this.iconUrl,
    this.bannerUrl,
    this.sortOrder = 0,
    this.isActive = true,
    this.specTemplateKeys = const <String>[],
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String slug;
  final String? parentId;
  final String iconUrl;
  final String? bannerUrl;
  final int sortOrder;
  final bool isActive;
  final List<String> specTemplateKeys;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isRootCategory => parentId == null || parentId!.isEmpty;

  factory CategoryModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return CategoryModel(
      id: doc.id,
      name: FirestoreParser.parseString(data['name'], fallback: 'Danh mục'),
      slug: FirestoreParser.parseString(data['slug'], fallback: doc.id),
      parentId: FirestoreParser.parseNullableString(data['parentId']),
      iconUrl: FirestoreParser.parseString(data['iconUrl']),
      bannerUrl: FirestoreParser.parseNullableString(data['bannerUrl']),
      sortOrder: FirestoreParser.parseInt(data['sortOrder']),
      isActive: FirestoreParser.parseBool(data['isActive'], fallback: true),
      specTemplateKeys: FirestoreParser.parseStringList(
        data['specTemplateKeys'],
      ),
      createdAt: FirestoreParser.parseDateTime(data['createdAt']),
      updatedAt: FirestoreParser.parseDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'slug': slug,
      'parentId': parentId,
      'iconUrl': iconUrl,
      'bannerUrl': bannerUrl,
      'sortOrder': sortOrder,
      'isActive': isActive,
      'specTemplateKeys': specTemplateKeys,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  @override
  List<Object?> get props => [
    id,
    name,
    slug,
    parentId,
    iconUrl,
    bannerUrl,
    sortOrder,
    isActive,
    specTemplateKeys,
  ];
}