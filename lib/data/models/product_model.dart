import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/firestore_parser.dart';

class ProductModel extends Equatable {
  const ProductModel({
    required this.id,
    required this.sku,
    required this.name,
    required this.nameLower,
    required this.searchKeywords,
    required this.categoryId,
    required this.parentCategoryId,
    required this.brandId,
    required this.brandName,
    required this.model,
    required this.price,
    this.salePrice,
    required this.effectivePrice,
    required this.stockQuantity,
    this.reservedQuantity = 0,
    required this.availableStock,
    required this.inStock,
    required this.thumbnailUrl,
    required this.imageUrls,
    required this.shortDescription,
    required this.description,
    required this.specifications,
    this.specFilterTags = const <String>[],
    this.warrantyMonths = 12,
    this.warrantyPolicy = 'Bảo hành chính hãng theo tiêu chuẩn nhà sản xuất.',
    this.ratingAvg = 0.0,
    this.ratingCount = 0,
    this.soldCount = 0,
    this.isFeatured = false,
    this.isNew = false,
    this.isOnSale = false,
    this.isActive = true,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String sku;
  final String name;
  final String nameLower;
  final List<String> searchKeywords;
  final String categoryId;
  final String parentCategoryId;
  final String brandId;
  final String brandName;
  final String model;

  /// Giá gốc và giá khuyến mãi luôn là số nguyên VND (int)
  final int price;
  final int? salePrice;
  final int effectivePrice;

  final int stockQuantity;
  final int reservedQuantity;
  final int availableStock;
  final bool inStock;

  final String thumbnailUrl;
  final List<String> imageUrls;
  final String shortDescription;
  final String description;
  final Map<String, String> specifications;
  final List<String> specFilterTags;
  final int warrantyMonths;
  final String warrantyPolicy;

  final double ratingAvg;
  final int ratingCount;
  final int soldCount;

  final bool isFeatured;
  final bool isNew;
  final bool isOnSale;
  final bool isActive;
  final bool isDeleted;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasDiscount =>
      salePrice != null && salePrice! > 0 && salePrice! < price;

  int get discountPercent => CurrencyFormatter.calculateDiscountPercent(
    originalPrice: price,
    salePrice: salePrice,
  );

  List<String> get galleryImages {
    final all = <String>{
      if (thumbnailUrl.isNotEmpty) thumbnailUrl,
      ...imageUrls.where((url) => url.isNotEmpty),
    }.toList(growable: false);
    return all;
  }

  /// Tạo danh sách từ khóa tìm kiếm không dấu/chữ thường từ Tên, SKU, Thương hiệu, Model
  static List<String> generateSearchKeywords({
    required String name,
    required String sku,
    required String brandName,
    required String model,
  }) {
    final rawText = '$name $sku $brandName $model'.toLowerCase();
    final normalized = _removeVietnameseDiacritics(rawText);
    final tokens = <String>{};

    for (final source in <String>[rawText, normalized]) {
      final words = source
          .split(RegExp(r'[^a-z0-9\+]+'))
          .map((w) => w.trim())
          .where((w) => w.length >= 2);
      for (final word in words) {
        tokens.add(word);
        // Tạo prefix từ 2 ký tự trở lên để hỗ trợ tìm kiếm nhanh
        for (var i = 2; i <= word.length && i <= 12; i++) {
          tokens.add(word.substring(0, i));
        }
      }
    }
    tokens.add(sku.toLowerCase());
    tokens.add(brandName.toLowerCase());
    tokens.add(model.toLowerCase());
    return tokens.toList(growable: false);
  }

  static String _removeVietnameseDiacritics(String input) {
    var result = input.toLowerCase();
    const vietnameseMap = <String, String>{
      'à|á|ạ|ả|ã|â|ầ|ấ|ậ|ẩ|ẫ|ă|ằ|ắ|ặ|ẳ|ẵ': 'a',
      'è|é|ẹ|ẻ|ẽ|ê|ề|ế|ệ|ể|ễ': 'e',
      'ì|í|ị|ỉ|ĩ': 'i',
      'ò|ó|ọ|ỏ|õ|ô|ồ|ố|ộ|ổ|ỗ|ơ|ờ|ớ|ợ|ở|ỡ': 'o',
      'ù|ú|ụ|ủ|ũ|ư|ừ|ứ|ự|ử|ữ': 'u',
      'ỳ|ý|ỵ|ỷ|ỹ': 'y',
      'đ': 'd',
    };
    vietnameseMap.forEach((pattern, replacement) {
      result = result.replaceAll(RegExp(pattern), replacement);
    });
    return result;
  }

  factory ProductModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawPrice = FirestoreParser.parseInt(data['price']);
    final safePrice = rawPrice < 0 ? 0 : rawPrice;

    final rawSalePrice = data['salePrice'] != null
        ? FirestoreParser.parseInt(data['salePrice'])
        : null;
    final validSalePrice =
    (rawSalePrice != null && rawSalePrice > 0 && rawSalePrice < safePrice)
        ? rawSalePrice
        : null;

    final effectivePrice = validSalePrice ?? safePrice;

    final stockQty = FirestoreParser.parseInt(data['stockQuantity']);
    final reservedQty = FirestoreParser.parseInt(data['reservedQuantity']);
    final computedAvailable = (stockQty - reservedQty).clamp(0, 999999);
    final availableStock = data['availableStock'] != null
        ? FirestoreParser.parseInt(
      data['availableStock'],
      fallback: computedAvailable,
    ).clamp(0, 999999)
        : computedAvailable;

    final rawSpecs = data['specifications'];
    final parsedSpecs = <String, String>{};
    if (rawSpecs is Map) {
      rawSpecs.forEach((key, value) {
        final k = key?.toString().trim() ?? '';
        final v = value?.toString().trim() ?? '';
        if (k.isNotEmpty && v.isNotEmpty) {
          parsedSpecs[k] = v;
        }
      });
    }

    final name = FirestoreParser.parseString(
      data['name'],
      fallback: 'Linh kiện điện tử',
    );
    final sku = FirestoreParser.parseString(
      data['sku'],
      fallback: doc.id.toUpperCase(),
    );
    final brandName = FirestoreParser.parseString(data['brandName']);
    final model = FirestoreParser.parseString(data['model']);

    final existingKeywords = FirestoreParser.parseStringList(
      data['searchKeywords'],
    );

    return ProductModel(
      id: doc.id,
      sku: sku,
      name: name,
      nameLower: FirestoreParser.parseString(
        data['nameLower'],
        fallback: name.toLowerCase(),
      ),
      searchKeywords: existingKeywords.isNotEmpty
          ? existingKeywords
          : generateSearchKeywords(
        name: name,
        sku: sku,
        brandName: brandName,
        model: model,
      ),
      categoryId: FirestoreParser.parseString(data['categoryId']),
      parentCategoryId: FirestoreParser.parseString(data['parentCategoryId']),
      brandId: FirestoreParser.parseString(data['brandId']),
      brandName: brandName,
      model: model,
      price: safePrice,
      salePrice: validSalePrice,
      effectivePrice: effectivePrice,
      stockQuantity: stockQty < 0 ? 0 : stockQty,
      reservedQuantity: reservedQty < 0 ? 0 : reservedQty,
      availableStock: availableStock,
      inStock: availableStock > 0,
      thumbnailUrl: FirestoreParser.parseString(data['thumbnailUrl']),
      imageUrls: FirestoreParser.parseStringList(data['imageUrls']),
      shortDescription: FirestoreParser.parseString(data['shortDescription']),
      description: FirestoreParser.parseString(data['description']),
      specifications: parsedSpecs,
      specFilterTags: FirestoreParser.parseStringList(data['specFilterTags']),
      warrantyMonths: FirestoreParser.parseInt(
        data['warrantyMonths'],
        fallback: 12,
      ),
      warrantyPolicy: FirestoreParser.parseString(
        data['warrantyPolicy'],
        fallback: 'Bảo hành chính hãng 1 đổi 1 trong 30 ngày đầu nếu lỗi NSX.',
      ),
      ratingAvg: FirestoreParser.parseDouble(data['ratingAvg']).clamp(0.0, 5.0),
      ratingCount: FirestoreParser.parseInt(data['ratingCount']),
      soldCount: FirestoreParser.parseInt(data['soldCount']),
      isFeatured: FirestoreParser.parseBool(data['isFeatured']),
      isNew: FirestoreParser.parseBool(data['isNew']),
      isOnSale: validSalePrice != null ||
          FirestoreParser.parseBool(data['isOnSale']),
      isActive: safePrice > 0 &&
          FirestoreParser.parseBool(data['isActive'], fallback: true),
      isDeleted: FirestoreParser.parseBool(data['isDeleted']),
      createdAt: FirestoreParser.parseDateTime(data['createdAt']),
      updatedAt: FirestoreParser.parseDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return <String, dynamic>{
      'id': id,
      'sku': sku,
      'name': name,
      'nameLower': name.toLowerCase(),
      'searchKeywords': searchKeywords,
      'categoryId': categoryId,
      'parentCategoryId': parentCategoryId,
      'brandId': brandId,
      'brandName': brandName,
      'model': model,
      'price': price,
      'salePrice': salePrice,
      'effectivePrice': salePrice ?? price,
      'stockQuantity': stockQuantity,
      'reservedQuantity': reservedQuantity,
      'availableStock': availableStock,
      'inStock': availableStock > 0,
      'thumbnailUrl': thumbnailUrl,
      'imageUrls': imageUrls,
      'shortDescription': shortDescription,
      'description': description,
      'specifications': specifications,
      'specFilterTags': specFilterTags,
      'warrantyMonths': warrantyMonths,
      'warrantyPolicy': warrantyPolicy,
      'ratingAvg': ratingAvg,
      'ratingCount': ratingCount,
      'soldCount': soldCount,
      'isFeatured': isFeatured,
      'isNew': isNew,
      'isOnSale': salePrice != null && salePrice! < price,
      'isActive': isActive,
      'isDeleted': isDeleted,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  @override
  List<Object?> get props => [
    id,
    sku,
    name,
    categoryId,
    parentCategoryId,
    brandId,
    price,
    salePrice,
    effectivePrice,
    availableStock,
    inStock,
    thumbnailUrl,
    ratingAvg,
    ratingCount,
    soldCount,
    isFeatured,
    isNew,
    isOnSale,
    isActive,
    isDeleted,
  ];
}