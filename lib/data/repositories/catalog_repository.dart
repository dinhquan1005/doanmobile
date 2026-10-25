import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/firestore_collections.dart';
import '../models/banner_model.dart';
import '../models/brand_model.dart';
import '../models/category_model.dart';
import '../models/coupon_model.dart';
import '../models/product_filter.dart';
import '../models/product_model.dart';
import '../models/review_model.dart';

class PaginatedProductsResult {
  const PaginatedProductsResult({
    required this.products,
    required this.lastDocument,
    required this.hasMore,
  });

  final List<ProductModel> products;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;
}

class HomeCatalogBundle {
  const HomeCatalogBundle({
    required this.banners,
    required this.categories,
    required this.brands,
    required this.activeCoupons,
    required this.featuredProducts,
    required this.newProducts,
    required this.saleProducts,
    required this.bestSellingProducts,
  });

  final List<BannerModel> banners;
  final List<CategoryModel> categories;
  final List<BrandModel> brands;
  final List<CouponModel> activeCoupons;
  final List<ProductModel> featuredProducts;
  final List<ProductModel> newProducts;
  final List<ProductModel> saleProducts;
  final List<ProductModel> bestSellingProducts;

  bool get isCatalogEmpty =>
      categories.isEmpty &&
          featuredProducts.isEmpty &&
          newProducts.isEmpty &&
          saleProducts.isEmpty &&
          bestSellingProducts.isEmpty;
}

class CatalogRepository {
  CatalogRepository({
    required FirebaseFirestore firestore,
    FirebaseStorage? storage,
    SharedPreferences? sharedPreferences,
  })  : _firestore = firestore,
        _storage = storage,
        _prefs = sharedPreferences;

  final FirebaseFirestore _firestore;
  final FirebaseStorage? _storage;
  final SharedPreferences? _prefs;

  static final Map<String, String> _storageUrlCache = <String, String>{};

  /// [VẤN ĐÁP] Chuyển đổi đường dẫn ảnh từ Firebase Storage sang HTTPS Download URL
  /// - Bộ nhớ đệm `_storageUrlCache`: Giảm thiểu tối đa số lượng request gọi lên Firebase Storage, tiết kiệm băng thông và tăng tốc độ hiển thị UI.
  Future<String> resolveStorageImageUrl(String rawUrlOrPath) async {
    final trimmed = rawUrlOrPath.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (_storageUrlCache.containsKey(trimmed)) {
      return _storageUrlCache[trimmed]!;
    }
    final storageInstance = _storage;
    if (storageInstance == null) {
      return '';
    }
    try {
      final Reference ref = trimmed.startsWith('gs://')
          ? storageInstance.refFromURL(trimmed)
          : storageInstance.ref(trimmed);
      final downloadUrl = await ref.getDownloadURL();
      _storageUrlCache[trimmed] = downloadUrl;
      return downloadUrl;
    } catch (_) {
      return '';
    }
  }

  /// [VẤN ĐÁP] Lấy danh sách Banner quảng cáo đang hoạt động
  Future<List<BannerModel>> fetchActiveBanners() async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.banners)
        .where('isActive', isEqualTo: true)
        .get();
    final banners =
    snapshot.docs.map(BannerModel.fromFirestore).toList(growable: false);
    final sorted = [...banners]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return sorted;
  }

  /// [VẤN ĐÁP] Lấy danh mục linh kiện (Category) xếp theo thứ tự hiển thị `sortOrder`
  Future<List<CategoryModel>> fetchCategories() async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.categories)
        .where('isActive', isEqualTo: true)
        .get();
    final categories =
    snapshot.docs.map(CategoryModel.fromFirestore).toList(growable: false);
    final sorted = [...categories]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return sorted;
  }

  /// [VẤN ĐÁP] Lấy danh sách thương hiệu sản xuất (ASUS, Intel, AMD, Corsair...)
  Future<List<BrandModel>> fetchBrands() async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.brands)
        .where('isActive', isEqualTo: true)
        .get();
    final brands =
    snapshot.docs.map(BrandModel.fromFirestore).toList(growable: false);
    final sorted = [...brands]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return sorted;
  }

  /// [VẤN ĐÁP] Lấy danh sách Voucher mã giảm giá đang còn hiệu lực
  /// Lọc theo thời gian UTC hiện tại: `startDate <= now <= endDate`
  Future<List<CouponModel>> fetchActiveCoupons() async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.coupons)
        .where('isActive', isEqualTo: true)
        .get();
    final now = DateTime.now().toUtc();
    return snapshot.docs
        .map(CouponModel.fromFirestore)
        .where((c) => c.isCurrentlyValid(now))
        .toList(growable: false);
  }

  /// [VẤN ĐÁP] Gói dữ liệu tổng hợp cho Trang chủ (Home Catalog Bundle)
  /// - Sử dụng `Future.wait`: Chạy song song 5 truy vấn đồng thời để giảm thiểu thời gian chờ tải trang.
  /// - Phân loại linh kiện: Sản phẩm nổi bật (Featured), Mới về (New), Đang giảm giá (Sale), Bán chạy nhất (Best Sellers).
  Future<HomeCatalogBundle> fetchHomeCatalogBundle() async {
    final results = await Future.wait<dynamic>([
      fetchActiveBanners(),
      fetchCategories(),
      fetchBrands(),
      fetchActiveCoupons(),
      _fetchActiveProductsPool(limit: 60),
    ]);

    final banners = results[0] as List<BannerModel>;
    final categories = results[1] as List<CategoryModel>;
    final brands = results[2] as List<BrandModel>;
    final coupons = results[3] as List<CouponModel>;
    final allProducts = results[4] as List<ProductModel>;

    final featured = allProducts
        .where((p) => p.isFeatured)
        .take(AppConstants.homeSectionLimit)
        .toList(growable: false);

    final newArrivals = [...allProducts]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final newProducts = newArrivals
        .take(AppConstants.homeSectionLimit)
        .toList(growable: false);

    final saleProducts = allProducts
        .where((p) => p.hasDiscount || p.isOnSale)
        .take(AppConstants.homeSectionLimit)
        .toList(growable: false);

    final bestSellers = [...allProducts]
      ..sort((a, b) => b.soldCount.compareTo(a.soldCount));
    final bestSellingProducts = bestSellers
        .take(AppConstants.homeSectionLimit)
        .toList(growable: false);

    return HomeCatalogBundle(
      banners: banners,
      categories: categories,
      brands: brands,
      activeCoupons: coupons,
      featuredProducts: featured,
      newProducts: newProducts,
      saleProducts: saleProducts,
      bestSellingProducts: bestSellingProducts,
    );
  }

  Future<List<ProductModel>> _fetchActiveProductsPool({int limit = 60}) async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.products)
        .where('isActive', isEqualTo: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map(ProductModel.fromFirestore)
        .where((p) => !p.isDeleted && p.isActive)
        .toList(growable: false);
  }

  /// [VẤN ĐÁP] Tìm kiếm, lọc đa điều kiện, sắp xếp và phân trang linh kiện từ Cloud Firestore
  /// - Phân trang con trỏ (Cursor Pagination): Sử dụng `startAfterDocument(startAfterDoc)` thay vì offset, giúp tốc độ truy vấn luôn là O(1) bất kể dữ liệu lớn.
  /// - Tìm kiếm SKU / Tên: Tách từ khóa thành token chữ thường và truy vấn mảng `searchKeywords` bằng toán tử `arrayContains`.
  /// - Lọc nâng cao: Lọc danh mục con/cha (`categoryId`), hãng (`brandId`), chỉ còn hàng (`inStock`), chỉ giảm giá (`isOnSale`).
  /// - Lọc khoảng giá (minPrice, maxPrice) & sắp xếp: Tinh chỉnh cục bộ trên tập kết quả để đảm bảo hiển thị giá tiền VND chuẩn xác.
  Future<PaginatedProductsResult> queryProducts({
    required ProductFilter filter,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDoc,
    int pageSize = AppConstants.defaultPageSize,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection(FirestoreCollections.products)
        .where('isActive', isEqualTo: true);

    if (filter.categoryId != null && filter.categoryId!.isNotEmpty) {
      query = query.where('categoryId', isEqualTo: filter.categoryId);
    } else if (filter.parentCategoryId != null &&
        filter.parentCategoryId!.isNotEmpty) {
      query = query.where(
        'parentCategoryId',
        isEqualTo: filter.parentCategoryId,
      );
    }

    if (filter.brandId != null && filter.brandId!.isNotEmpty) {
      query = query.where('brandId', isEqualTo: filter.brandId);
    }

    if (filter.onlyInStock) {
      query = query.where('inStock', isEqualTo: true);
    }

    if (filter.onlyOnSale) {
      query = query.where('isOnSale', isEqualTo: true);
    }

    final trimmedSearch = filter.searchQuery.trim().toLowerCase();
    if (trimmedSearch.isNotEmpty) {
      final firstToken = trimmedSearch
          .split(RegExp(r'\s+'))
          .firstWhere((t) => t.isNotEmpty, orElse: () => '');
      if (firstToken.length >= 2) {
        query = query.where('searchKeywords', arrayContains: firstToken);
      }
    } else if (filter.specTag != null && filter.specTag!.isNotEmpty) {
      query = query.where('specFilterTags', arrayContains: filter.specTag);
    }

    if (startAfterDoc != null) {
      query = query.startAfterDocument(startAfterDoc);
    }

    // Tải batch từ Firestore để lọc chi tiết đa điều kiện và sắp xếp chính xác
    final fetchLimit = pageSize * 3;
    final snapshot = await query.limit(fetchLimit).get();

    var items = snapshot.docs
        .map(ProductModel.fromFirestore)
        .where((product) => !product.isDeleted && product.isActive)
        .toList();

    // Lọc bổ sung khi người dùng nhập nhiều từ khóa (tên, SKU, thương hiệu, model)
    if (trimmedSearch.isNotEmpty) {
      final queryWords = trimmedSearch
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList(growable: false);
      items = items.where((product) {
        final searchableBlob =
            '${product.nameLower} ${product.sku.toLowerCase()} '
            '${product.brandName.toLowerCase()} ${product.model.toLowerCase()} '
            '${product.searchKeywords.join(' ')}';
        return queryWords.every(searchableBlob.contains);
      }).toList();
    }

    if (filter.specTag != null && filter.specTag!.isNotEmpty) {
      items = items
          .where((p) => p.specFilterTags.contains(filter.specTag))
          .toList();
    }

    if (filter.minPrice != null) {
      items = items
          .where((p) => p.effectivePrice >= filter.minPrice!)
          .toList();
    }

    if (filter.maxPrice != null) {
      items = items
          .where((p) => p.effectivePrice <= filter.maxPrice!)
          .toList();
    }

    switch (filter.sortOption) {
      case ProductSortOption.priceAsc:
        items.sort((a, b) => a.effectivePrice.compareTo(b.effectivePrice));
      case ProductSortOption.priceDesc:
        items.sort((a, b) => b.effectivePrice.compareTo(a.effectivePrice));
      case ProductSortOption.popular:
        items.sort((a, b) => b.soldCount.compareTo(a.soldCount));
      case ProductSortOption.newest:
        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    final pagedItems = items.take(pageSize).toList(growable: false);
    final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
    final hasMore = snapshot.docs.length >= fetchLimit || items.length > pageSize;

    return PaginatedProductsResult(
      products: pagedItems,
      lastDocument: lastDoc,
      hasMore: hasMore,
    );
  }

  Future<ProductModel?> fetchProductById(String productId) async {
    final doc = await _firestore
        .collection(FirestoreCollections.products)
        .doc(productId)
        .get();
    if (!doc.exists) {
      return null;
    }
    final product = ProductModel.fromFirestore(doc);
    if (product.isDeleted || !product.isActive) {
      return null;
    }
    return product;
  }

  Future<List<ProductModel>> fetchRelatedProducts({
    required String categoryId,
    required String excludeProductId,
    int limit = 6,
  }) async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.products)
        .where('isActive', isEqualTo: true)
        .where('categoryId', isEqualTo: categoryId)
        .limit(limit + 2)
        .get();

    return snapshot.docs
        .map(ProductModel.fromFirestore)
        .where((p) => !p.isDeleted && p.id != excludeProductId)
        .take(limit)
        .toList(growable: false);
  }

  Future<List<ReviewModel>> fetchProductReviews(String productId) async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.reviews)
        .where('productId', isEqualTo: productId)
        .where('status', isEqualTo: 'approved')
        .get();

    final reviews =
    snapshot.docs.map(ReviewModel.fromFirestore).toList(growable: false);
    final sorted = [...reviews]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  /// Lưu và tải danh sách sản phẩm đã xem gần đây
  Future<void> recordRecentlyViewedProduct(String productId) async {
    final prefs = _prefs;
    if (prefs == null || productId.trim().isEmpty) {
      return;
    }
    final existing =
        prefs.getStringList(AppConstants.prefRecentProductsKey) ?? <String>[];
    final updated = <String>[
      productId,
      ...existing.where((id) => id != productId),
    ].take(10).toList(growable: false);
    await prefs.setStringList(AppConstants.prefRecentProductsKey, updated);
  }

  List<String> getRecentlyViewedProductIds() {
    return _prefs?.getStringList(AppConstants.prefRecentProductsKey) ??
        const <String>[];
  }

  Future<List<ProductModel>> fetchProductsByIds(List<String> ids) async {
    if (ids.isEmpty) {
      return const <ProductModel>[];
    }
    final limitedIds = ids.take(10).toList(growable: false);
    final snapshot = await _firestore
        .collection(FirestoreCollections.products)
        .where(FieldPath.documentId, whereIn: limitedIds)
        .get();

    final mapById = <String, ProductModel>{};
    for (final doc in snapshot.docs) {
      final model = ProductModel.fromFirestore(doc);
      if (model.isActive && !model.isDeleted) {
        mapById[model.id] = model;
      }
    }

    return limitedIds
        .map((id) => mapById[id])
        .whereType<ProductModel>()
        .toList(growable: false);
  }

  /// [VẤN ĐÁP] Thêm mới linh kiện vào Cloud Firestore (Dành cho Quản trị viên)
  /// Sử dụng `doc(product.id).set(...)` để tạo mới document hoàn chỉnh.
  Future<void> createProduct(ProductModel product) async {
    final ref = _firestore.collection(FirestoreCollections.products).doc(product.id);
    await ref.set(product.toFirestoreMap());
  }

  /// [VẤN ĐÁP] Cập nhật thông tin linh kiện trên Cloud Firestore (Dành cho Quản trị viên)
  /// Cập nhật giá bán, số lượng tồn kho và tự động đóng dấu thời gian cập nhật bằng `FieldValue.serverTimestamp()`.
  Future<void> updateProduct(ProductModel product) async {
    final ref = _firestore.collection(FirestoreCollections.products).doc(product.id);
    await ref.update({
      ...product.toFirestoreMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// [VẤN ĐÁP] Xóa linh kiện (Hỗ trợ Xóa mềm & Xóa vĩnh viễn)
  /// - `permanent == false` (Xóa mềm - Soft Delete): Đánh dấu cờ `isDeleted = true, isActive = false`, bảo toàn dữ liệu lịch sử cho các đơn hàng cũ.
  /// - `permanent == true` (Xóa cứng - Hard Delete): Xóa hoàn toàn document khỏi Firestore.
  Future<void> deleteProduct(String productId, {bool permanent = false}) async {
    final ref = _firestore.collection(FirestoreCollections.products).doc(productId);
    if (permanent) {
      await ref.delete();
    } else {
      await ref.update({
        'isDeleted': true,
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}