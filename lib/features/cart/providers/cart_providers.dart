import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../data/models/cart_model.dart';
import '../../../data/models/coupon_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/cart_repository.dart';
import '../../auth/providers/auth_providers.dart';

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  SharedPreferences? prefs;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
  } catch (_) {
    prefs = null;
  }
  return CartRepository(
    firestore: firestore,
    sharedPreferences: prefs,
  );
});

class CartViewState {
  const CartViewState({
    required this.summary,
    this.isLoading = false,
    this.isApplyingCoupon = false,
    this.errorMessage,
    this.infoMessage,
  });

  final CartSummary summary;
  final bool isLoading;
  final bool isApplyingCoupon;
  final String? errorMessage;
  final String? infoMessage;

  CartViewState copyWith({
    CartSummary? summary,
    bool? isLoading,
    bool? isApplyingCoupon,
    String? errorMessage,
    bool clearError = false,
    String? infoMessage,
    bool clearInfo = false,
  }) {
    return CartViewState(
      summary: summary ?? this.summary,
      isLoading: isLoading ?? this.isLoading,
      isApplyingCoupon: isApplyingCoupon ?? this.isApplyingCoupon,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      infoMessage: clearInfo ? null : (infoMessage ?? this.infoMessage),
    );
  }
}

class CartController extends StateNotifier<CartViewState> {
  CartController({
    required CartRepository repository,
    required FirebaseAuth firebaseAuth,
    required String? initialUserId,
  })  : _repository = repository,
        _firebaseAuth = firebaseAuth,
        _currentUserId = initialUserId ?? firebaseAuth.currentUser?.uid,
        super(
          const CartViewState(
            summary: CartSummary(items: <ResolvedCartItem>[]),
            isLoading: true,
          ),
        ) {
    _initializeCart();
  }

  final CartRepository _repository;
  final FirebaseAuth _firebaseAuth;
  String? _currentUserId;
  StreamSubscription<CartDocumentModel>? _remoteCartSubscription;
  List<CartItemEntry> _rawEntries = const <CartItemEntry>[];
  final Map<String, ProductModel> _cachedProducts = <String, ProductModel>{};
  String? _appliedCouponCode;
  CouponModel? _validatedCoupon;

  String? get _effectiveUserId =>
      _currentUserId ?? _firebaseAuth.currentUser?.uid;

  Future<void> _initializeCart() async {
    final uid = _effectiveUserId;
    if (uid != null && uid.isNotEmpty) {
      await _syncAndListenRemoteCart(uid);
    } else {
      final guestDoc = _repository.loadGuestCart();
      _rawEntries = guestDoc.items;
      _appliedCouponCode = guestDoc.appliedCouponCode;
      await _rebuildResolvedSummary(fetchRemoteProducts: true);
    }
  }

  Future<void> onAuthUserChanged(String? newUserId) async {
    final resolvedUid = newUserId ?? _firebaseAuth.currentUser?.uid;
    if (_currentUserId == resolvedUid) {
      return;
    }
    _currentUserId = resolvedUid;
    await _remoteCartSubscription?.cancel();
    _remoteCartSubscription = null;

    if (resolvedUid != null && resolvedUid.isNotEmpty) {
      await _syncAndListenRemoteCart(resolvedUid);
    } else {
      final guestDoc = _repository.loadGuestCart();
      _rawEntries = guestDoc.items;
      _appliedCouponCode = guestDoc.appliedCouponCode;
      _validatedCoupon = null;
      await _rebuildResolvedSummary(fetchRemoteProducts: true);
    }
  }

  Future<void> _syncAndListenRemoteCart(String userId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final mergedDoc = await _repository.mergeGuestCartIntoUserCart(userId);
      _rawEntries = mergedDoc.items;
      _appliedCouponCode = mergedDoc.appliedCouponCode;
      await _rebuildResolvedSummary(fetchRemoteProducts: true);

      _remoteCartSubscription = _repository.watchUserCart(userId).listen(
        (remoteDoc) async {
          _rawEntries = remoteDoc.items;
          _appliedCouponCode = remoteDoc.appliedCouponCode;
          await _rebuildResolvedSummary(fetchRemoteProducts: false);
        },
        onError: (_) {
          // Giữ nguyên trạng thái cục bộ nếu stream tạm thời mất quyền
        },
      );
    } catch (_) {
      // Fallback an toàn về dữ liệu đang có trong bộ nhớ nếu Firestore chưa cấu hình rules
      final guestDoc = _repository.loadGuestCart();
      if (_rawEntries.isEmpty && guestDoc.items.isNotEmpty) {
        _rawEntries = guestDoc.items;
      }
      await _rebuildResolvedSummary(fetchRemoteProducts: true);
    }
  }

  Future<void> refreshLatestPricesAndStock() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await _rebuildResolvedSummary(fetchRemoteProducts: true);
  }

  Future<void> _rebuildResolvedSummary({bool fetchRemoteProducts = true}) async {
    try {
      if (_rawEntries.isEmpty) {
        state = state.copyWith(
          summary: const CartSummary(items: <ResolvedCartItem>[]),
          isLoading: false,
        );
        return;
      }

      final missingIds = _rawEntries
          .map((e) => e.productId)
          .where((id) => !_cachedProducts.containsKey(id))
          .toList(growable: false);

      if (fetchRemoteProducts || missingIds.isNotEmpty) {
        final idsToFetch = fetchRemoteProducts
            ? _rawEntries.map((e) => e.productId).toList(growable: false)
            : missingIds;
        final latestMap = await _repository.fetchLatestProductsMap(idsToFetch);
        _cachedProducts.addAll(latestMap);
      }

      final resolvedItems = _rawEntries
          .map(
            (entry) => ResolvedCartItem(
              entry: entry,
              product: _cachedProducts[entry.productId],
            ),
          )
          .toList(growable: false);

      final selectedSubtotal = resolvedItems
          .where((e) => e.isSelected)
          .fold<int>(
            0,
            (int accumulator, ResolvedCartItem item) =>
                accumulator + item.lineSubtotal,
          );

      CouponModel? activeCoupon = _validatedCoupon;
      String? couponWarning;

      if (_appliedCouponCode != null &&
          _appliedCouponCode!.trim().isNotEmpty &&
          selectedSubtotal > 0) {
        try {
          activeCoupon = await _repository.validateCoupon(
            rawCode: _appliedCouponCode!,
            currentSubtotal: selectedSubtotal,
          );
          _validatedCoupon = activeCoupon;
        } on AppFailure catch (e) {
          activeCoupon = null;
          couponWarning = e.message;
        } catch (_) {
          activeCoupon = null;
        }
      } else {
        activeCoupon = null;
      }

      state = state.copyWith(
        summary: CartSummary(
          items: resolvedItems,
          appliedCoupon: activeCoupon,
          couponValidationError: couponWarning,
        ),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Lỗi khi đồng bộ giỏ hàng: $e',
      );
    }
  }

  /// Cập nhật UI ngay lập tức (Optimistic Update) rồi lưu xuống cả Local + Firestore
  Future<void> _applyOptimisticAndPersist() async {
    await _rebuildResolvedSummary(fetchRemoteProducts: false);

    // Luôn lưu bản sao vào SharedPreferences để không bao giờ mất giỏ hàng
    try {
      await _repository.saveGuestCart(
        items: _rawEntries,
        appliedCouponCode: _appliedCouponCode,
      );
    } catch (_) {}

    final uid = _effectiveUserId;
    if (uid != null && uid.isNotEmpty) {
      try {
        await _repository.saveUserCart(
          userId: uid,
          items: _rawEntries,
          appliedCouponCode: _appliedCouponCode,
        );
      } catch (e) {
        state = state.copyWith(
          errorMessage:
              'Đã cập nhật trên máy nhưng chưa thể đồng bộ lên Firestore: $e',
        );
      }
    }
  }

  Future<bool> addProduct({
    required String productId,
    int quantityToAdd = 1,
  }) async {
    if (quantityToAdd <= 0) {
      return false;
    }
    state = state.copyWith(clearError: true, clearInfo: true);

    try {
      final latestMap =
          await _repository.fetchLatestProductsMap(<String>[productId]);
      final latestProduct = latestMap[productId] ?? _cachedProducts[productId];

      if (latestProduct == null ||
          !latestProduct.isActive ||
          latestProduct.isDeleted) {
        state = state.copyWith(
          errorMessage: 'Sản phẩm này hiện không còn kinh doanh.',
        );
        return false;
      }
      _cachedProducts[productId] = latestProduct;

      if (latestProduct.availableStock <= 0) {
        state = state.copyWith(
          errorMessage: 'Sản phẩm "${latestProduct.name}" hiện đã hết hàng.',
        );
        return false;
      }

      final existingIndex =
          _rawEntries.indexWhere((e) => e.productId == productId);
      final currentQtyInCart =
          existingIndex >= 0 ? _rawEntries[existingIndex].quantity : 0;
      final targetQty = currentQtyInCart + quantityToAdd;

      if (targetQty > latestProduct.availableStock) {
        state = state.copyWith(
          errorMessage:
              'Kho chỉ còn ${latestProduct.availableStock} sản phẩm "${latestProduct.name}" (trong giỏ đã có $currentQtyInCart).',
        );
        return false;
      }

      final updatedList = [..._rawEntries];
      if (existingIndex >= 0) {
        updatedList[existingIndex] = updatedList[existingIndex].copyWith(
          quantity: targetQty,
          isSelected: true,
        );
      } else {
        updatedList.add(
          CartItemEntry(
            productId: productId,
            quantity: targetQty,
            isSelected: true,
            addedAt: DateTime.now().toUtc(),
          ),
        );
      }

      _rawEntries = updatedList;
      await _applyOptimisticAndPersist();
      state = state.copyWith(
        infoMessage: 'Đã thêm "${latestProduct.name}" vào giỏ hàng.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Không thể thêm sản phẩm vào giỏ hàng: $e',
      );
      return false;
    }
  }

  Future<void> updateQuantity({
    required String productId,
    required int newQuantity,
  }) async {
    state = state.copyWith(clearError: true, clearInfo: true);
    if (newQuantity <= 0) {
      await removeItem(productId);
      return;
    }

    final cached = _cachedProducts[productId];
    if (cached != null &&
        cached.availableStock > 0 &&
        newQuantity > cached.availableStock) {
      state = state.copyWith(
        errorMessage:
            'Sản phẩm "${cached.name}" chỉ còn tối đa ${cached.availableStock} sản phẩm trong kho.',
      );
      newQuantity = cached.availableStock;
    }

    _rawEntries = _rawEntries.map((entry) {
      if (entry.productId == productId) {
        return entry.copyWith(quantity: newQuantity);
      }
      return entry;
    }).toList(growable: false);

    await _applyOptimisticAndPersist();
  }

  Future<void> toggleSelectItem(String productId, bool isSelected) async {
    _rawEntries = _rawEntries.map((entry) {
      if (entry.productId == productId) {
        return entry.copyWith(isSelected: isSelected);
      }
      return entry;
    }).toList(growable: false);
    await _applyOptimisticAndPersist();
  }

  Future<void> toggleSelectAll(bool selectAll) async {
    _rawEntries = _rawEntries
        .map((entry) => entry.copyWith(isSelected: selectAll))
        .toList(growable: false);
    await _applyOptimisticAndPersist();
  }

  Future<void> removeItem(String productId) async {
    _rawEntries = _rawEntries
        .where((entry) => entry.productId != productId)
        .toList(growable: false);
    await _applyOptimisticAndPersist();
  }

  Future<void> removeSelectedItemsAfterOrder() async {
    _rawEntries = _rawEntries
        .where((entry) => !entry.isSelected)
        .toList(growable: false);
    _appliedCouponCode = null;
    _validatedCoupon = null;
    await _applyOptimisticAndPersist();
  }

  Future<bool> applyCouponCode(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Vui lòng nhập mã giảm giá.',
      );
      return false;
    }

    state = state.copyWith(
      isApplyingCoupon: true,
      clearError: true,
      clearInfo: true,
    );

    try {
      final coupon = await _repository.validateCoupon(
        rawCode: code,
        currentSubtotal: state.summary.subtotal,
      );
      _appliedCouponCode = coupon.code;
      _validatedCoupon = coupon;
      await _applyOptimisticAndPersist();
      state = state.copyWith(
        isApplyingCoupon: false,
        infoMessage: 'Đã áp dụng mã giảm giá ${coupon.code} thành công!',
      );
      return true;
    } on AppFailure catch (e) {
      state = state.copyWith(
        isApplyingCoupon: false,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isApplyingCoupon: false,
        errorMessage: 'Không thể áp dụng mã giảm giá: $e',
      );
      return false;
    }
  }

  Future<void> removeCoupon() async {
    _appliedCouponCode = null;
    _validatedCoupon = null;
    await _applyOptimisticAndPersist();
  }

  @override
  void dispose() {
    _remoteCartSubscription?.cancel();
    super.dispose();
  }
}

final cartControllerProvider =
    StateNotifierProvider<CartController, CartViewState>((ref) {
  final repo = ref.watch(cartRepositoryProvider);
  final firebaseAuth = ref.watch(firebaseAuthProvider);
  final initialUid =
      ref.read(authStateChangesProvider).valueOrNull?.uid ??
          firebaseAuth.currentUser?.uid;

  final controller = CartController(
    repository: repo,
    firebaseAuth: firebaseAuth,
    initialUserId: initialUid,
  );

  ref.listen(authStateChangesProvider, (previous, next) {
    controller.onAuthUserChanged(next.valueOrNull?.uid);
  });

  return controller;
});

final cartTotalItemCountProvider = Provider<int>((ref) {
  return ref.watch(cartControllerProvider).summary.totalItemCount;
});
