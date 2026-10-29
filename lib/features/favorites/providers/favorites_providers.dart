import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/favorites_repository.dart';
import '../../auth/providers/auth_providers.dart';

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  SharedPreferences? prefs;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
  } catch (_) {
    prefs = null;
  }
  return FavoritesRepository(
    firestore: firestore,
    sharedPreferences: prefs,
  );
});

class FavoritesController extends StateNotifier<Set<String>> {
  FavoritesController({
    required FavoritesRepository repository,
    required String? initialUserId,
  })  : _repository = repository,
        _currentUserId = initialUserId,
        super(const <String>{}) {
    _initialize();
  }

  final FavoritesRepository _repository;
  String? _currentUserId;
  StreamSubscription<Set<String>>? _subscription;

  Future<void> _initialize() async {
    final uid = _currentUserId;
    if (uid != null && uid.isNotEmpty) {
      await _syncAndListenRemote(uid);
    } else {
      state = _repository.loadGuestFavoriteIds();
    }
  }

  Future<void> onAuthUserChanged(String? newUserId) async {
    if (_currentUserId == newUserId) {
      return;
    }
    _currentUserId = newUserId;
    await _subscription?.cancel();
    _subscription = null;

    if (newUserId != null && newUserId.isNotEmpty) {
      await _syncAndListenRemote(newUserId);
    } else {
      state = _repository.loadGuestFavoriteIds();
    }
  }

  Future<void> _syncAndListenRemote(String userId) async {
    final merged = await _repository.mergeGuestFavoritesIntoUser(userId);
    state = merged;
    _subscription = _repository.watchUserFavoriteProductIds(userId).listen(
          (ids) {
        state = ids;
      },
    );
  }

  Future<bool> toggleFavorite(String productId) async {
    final isCurrentlyFav = state.contains(productId);
    final updated = <String>{...state};
    if (isCurrentlyFav) {
      updated.remove(productId);
    } else {
      updated.add(productId);
    }
    state = updated;

    final uid = _currentUserId;
    if (uid != null && uid.isNotEmpty) {
      if (isCurrentlyFav) {
        await _repository.removeFavorite(userId: uid, productId: productId);
      } else {
        await _repository.addFavorite(userId: uid, productId: productId);
      }
    } else {
      await _repository.saveGuestFavoriteIds(updated);
    }
    return !isCurrentlyFav;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final favoritesControllerProvider =
StateNotifierProvider<FavoritesController, Set<String>>((ref) {
  final repo = ref.watch(favoritesRepositoryProvider);
  final initialUid = ref.read(authStateChangesProvider).valueOrNull?.uid;
  final controller = FavoritesController(
    repository: repo,
    initialUserId: initialUid,
  );

  ref.listen(authStateChangesProvider, (previous, next) {
    controller.onAuthUserChanged(next.valueOrNull?.uid);
  });

  return controller;
});

final isProductFavoriteProvider =
Provider.family<bool, String>((ref, productId) {
  final favIds = ref.watch(favoritesControllerProvider);
  return favIds.contains(productId);
});

final favoriteProductsListProvider =
FutureProvider<List<ProductModel>>((ref) async {
  final favIds = ref.watch(favoritesControllerProvider);
  return ref.watch(favoritesRepositoryProvider).fetchFavoriteProducts(favIds);
});