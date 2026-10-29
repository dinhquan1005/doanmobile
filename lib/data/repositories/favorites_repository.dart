import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/firestore_collections.dart';
import '../models/favorite_model.dart';
import '../models/product_model.dart';

class FavoritesRepository {
  FavoritesRepository({
    required FirebaseFirestore firestore,
    SharedPreferences? sharedPreferences,
  })  : _firestore = firestore,
        _prefs = sharedPreferences;

  final FirebaseFirestore _firestore;
  final SharedPreferences? _prefs;

  static const String _prefGuestFavoritesKey = 'pref_guest_favorite_ids';

  Set<String> loadGuestFavoriteIds() {
    final list =
        _prefs?.getStringList(_prefGuestFavoritesKey) ?? const <String>[];
    return list.where((id) => id.trim().isNotEmpty).toSet();
  }

  Future<void> saveGuestFavoriteIds(Set<String> ids) async {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    await prefs.setStringList(
      _prefGuestFavoritesKey,
      ids.toList(growable: false),
    );
  }

  Future<Set<String>> fetchUserFavoriteProductIds(String userId) async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.favorites)
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.docs
        .map(FavoriteModel.fromFirestore)
        .map((fav) => fav.productId)
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Stream<Set<String>> watchUserFavoriteProductIds(String userId) {
    return _firestore
        .collection(FirestoreCollections.favorites)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map(FavoriteModel.fromFirestore)
          .map((fav) => fav.productId)
          .where((id) => id.isNotEmpty)
          .toSet(),
    );
  }

  Future<void> addFavorite({
    required String userId,
    required String productId,
  }) async {
    final id = FavoriteModel.buildId(userId: userId, productId: productId);
    final favorite = FavoriteModel(
      id: id,
      userId: userId,
      productId: productId,
      createdAt: DateTime.now().toUtc(),
    );
    await _firestore
        .collection(FirestoreCollections.favorites)
        .doc(id)
        .set(favorite.toFirestoreMap());
  }

  Future<void> removeFavorite({
    required String userId,
    required String productId,
  }) async {
    final id = FavoriteModel.buildId(userId: userId, productId: productId);
    await _firestore
        .collection(FirestoreCollections.favorites)
        .doc(id)
        .delete();
  }

  /// Hợp nhất danh sách yêu thích cục bộ lên Cloud Firestore khi đăng nhập
  Future<Set<String>> mergeGuestFavoritesIntoUser(String userId) async {
    final guestIds = loadGuestFavoriteIds();
    if (guestIds.isNotEmpty) {
      final batch = _firestore.batch();
      final now = DateTime.now().toUtc();
      for (final productId in guestIds) {
        final docId =
        FavoriteModel.buildId(userId: userId, productId: productId);
        final docRef =
        _firestore.collection(FirestoreCollections.favorites).doc(docId);
        batch.set(
          docRef,
          FavoriteModel(
            id: docId,
            userId: userId,
            productId: productId,
            createdAt: now,
          ).toFirestoreMap(),
        );
      }
      await batch.commit();
      await _prefs?.remove(_prefGuestFavoritesKey);
    }
    return fetchUserFavoriteProductIds(userId);
  }

  Future<List<ProductModel>> fetchFavoriteProducts(
      Set<String> productIds,
      ) async {
    if (productIds.isEmpty) {
      return const <ProductModel>[];
    }
    final idList = productIds.toList(growable: false);
    final products = <ProductModel>[];

    for (var i = 0; i < idList.length; i += 10) {
      final chunk = idList.sublist(
        i,
        i + 10 > idList.length ? idList.length : i + 10,
      );
      final snapshot = await _firestore
          .collection(FirestoreCollections.products)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snapshot.docs) {
        final model = ProductModel.fromFirestore(doc);
        if (model.isActive && !model.isDeleted) {
          products.add(model);
        }
      }
    }
    return products;
  }
}