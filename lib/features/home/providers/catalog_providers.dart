import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../data/datasources/catalog_seed_service.dart';
import '../../../data/models/brand_model.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/review_model.dart';
import '../../../data/repositories/catalog_repository.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final storage = ref.watch(firebaseStorageProvider);
  SharedPreferences? prefs;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
  } catch (_) {
    prefs = null;
  }
  return CatalogRepository(
    firestore: firestore,
    storage: storage,
    sharedPreferences: prefs,
  );
});

final catalogSeedServiceProvider = Provider<CatalogSeedService>((ref) {
  return CatalogSeedService(ref.watch(firestoreProvider));
});

final storageDownloadUrlProvider =
FutureProvider.family<String, String>((ref, rawPath) async {
  return ref.watch(catalogRepositoryProvider).resolveStorageImageUrl(rawPath);
});

final homeCatalogBundleProvider =
FutureProvider<HomeCatalogBundle>((ref) async {
  return ref.watch(catalogRepositoryProvider).fetchHomeCatalogBundle();
});

final categoriesListProvider = FutureProvider<List<CategoryModel>>((ref) async {
  return ref.watch(catalogRepositoryProvider).fetchCategories();
});

final brandsListProvider = FutureProvider<List<BrandModel>>((ref) async {
  return ref.watch(catalogRepositoryProvider).fetchBrands();
});

final productDetailProvider =
FutureProvider.family<ProductModel?, String>((ref, productId) async {
  final repo = ref.watch(catalogRepositoryProvider);
  final product = await repo.fetchProductById(productId);
  if (product != null) {
    await repo.recordRecentlyViewedProduct(product.id);
    ref.invalidate(recentlyViewedProductsProvider);
  }
  return product;
});

final relatedProductsProvider = FutureProvider.family<List<ProductModel>,
    ({String categoryId, String excludeId})>((ref, params) async {
  return ref.watch(catalogRepositoryProvider).fetchRelatedProducts(
    categoryId: params.categoryId,
    excludeProductId: params.excludeId,
  );
});

final productReviewsProvider =
FutureProvider.family<List<ReviewModel>, String>((ref, productId) async {
  return ref.watch(catalogRepositoryProvider).fetchProductReviews(productId);
});

final recentlyViewedProductsProvider =
FutureProvider<List<ProductModel>>((ref) async {
  final repo = ref.watch(catalogRepositoryProvider);
  final ids = repo.getRecentlyViewedProductIds();
  return repo.fetchProductsByIds(ids);
});