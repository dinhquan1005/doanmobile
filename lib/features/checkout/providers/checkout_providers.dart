import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../data/models/address_model.dart';
import '../../../data/models/order_model.dart';
import '../../../data/repositories/order_repository.dart';
import '../../auth/providers/auth_providers.dart';
import '../../cart/providers/cart_providers.dart';
import '../../home/providers/catalog_providers.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(
    firestore: ref.watch(firestoreProvider),
    firebaseAuth: ref.watch(firebaseAuthProvider),
    functions: ref.watch(cloudFunctionsProvider),
  );
});

final userAddressesStreamProvider =
    StreamProvider<List<ShippingAddressModel>>((ref) {
  final user = ref.watch(authStateChangesProvider).valueOrNull ??
      ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) {
    return Stream.value(const <ShippingAddressModel>[]);
  }
  return ref.watch(orderRepositoryProvider).watchUserAddresses(user.uid);
});

class CheckoutSessionState {
  const CheckoutSessionState({
    required this.idempotencyKey,
    this.selectedAddress,
    this.shippingMethod = 'standard',
    this.paymentMethod = 'COD',
    this.isSubmitting = false,
    this.errorMessage,
  });

  final String idempotencyKey;
  final ShippingAddressModel? selectedAddress;
  final String shippingMethod; // 'standard' | 'express'
  final String paymentMethod; // 'COD'
  final bool isSubmitting;
  final String? errorMessage;

  int calculateShippingFee(int subtotalAfterDiscount) {
    if (shippingMethod == 'express') {
      return AppConstants.defaultExpressShippingFee;
    }
    return subtotalAfterDiscount >= AppConstants.defaultFreeShippingThreshold
        ? 0
        : AppConstants.defaultStandardShippingFee;
  }

  CheckoutSessionState copyWith({
    String? idempotencyKey,
    ShippingAddressModel? selectedAddress,
    bool clearSelectedAddress = false,
    String? shippingMethod,
    String? paymentMethod,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CheckoutSessionState(
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      selectedAddress: clearSelectedAddress
          ? null
          : (selectedAddress ?? this.selectedAddress),
      shippingMethod: shippingMethod ?? this.shippingMethod,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class CheckoutController extends StateNotifier<CheckoutSessionState> {
  CheckoutController(this._ref)
      : super(CheckoutSessionState(idempotencyKey: const Uuid().v4()));

  final Ref _ref;

  void selectAddress(ShippingAddressModel address) {
    state = state.copyWith(selectedAddress: address, clearError: true);
  }

  void setShippingMethod(String method) {
    state = state.copyWith(shippingMethod: method, clearError: true);
  }

  void setPaymentMethod(String method) {
    state = state.copyWith(paymentMethod: method, clearError: true);
  }

  Future<bool> saveAddress(ShippingAddressModel address) async {
    final user = _ref.read(authStateChangesProvider).valueOrNull ??
        _ref.read(firebaseAuthProvider).currentUser;
    if (user == null) {
      state = state.copyWith(
        errorMessage: 'Vui lòng đăng nhập để lưu địa chỉ.',
      );
      return false;
    }
    try {
      final saved = await _ref.read(orderRepositoryProvider).saveUserAddress(
            userId: user.uid,
            address: address,
          );
      state = state.copyWith(selectedAddress: saved, clearError: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Không thể lưu địa chỉ giao hàng: $e',
      );
      return false;
    }
  }

  Future<void> deleteAddress(String addressId) async {
    final user = _ref.read(authStateChangesProvider).valueOrNull ??
        _ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;
    try {
      await _ref.read(orderRepositoryProvider).deleteUserAddress(
            userId: user.uid,
            addressId: addressId,
          );
      if (state.selectedAddress?.id == addressId) {
        state = state.copyWith(clearSelectedAddress: true);
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Không thể xóa địa chỉ: $e');
    }
  }

  Future<OrderModel?> submitOrder({String? customerNote}) async {
    final cartSummary = _ref.read(cartControllerProvider).summary;
    final selectedItems = cartSummary.selectedItems;

    if (selectedItems.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Không có sản phẩm nào được chọn để thanh toán.',
      );
      return null;
    }

    final address = state.selectedAddress;
    if (address == null) {
      state = state.copyWith(
        errorMessage: 'Vui lòng thêm hoặc chọn địa chỉ nhận hàng.',
      );
      return null;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final requestedItems = selectedItems
          .map(
            (item) => OrderRequestedItem(
              productId: item.productId,
              quantity: item.quantity,
            ),
          )
          .toList(growable: false);

      final order = await _ref.read(orderRepositoryProvider).placeOrder(
            idempotencyKey: state.idempotencyKey,
            requestedItems: requestedItems,
            shippingAddress: address,
            shippingMethod: state.shippingMethod,
            paymentMethod: state.paymentMethod,
            couponCode: cartSummary.appliedCoupon?.code,
            customerNote: customerNote,
          );

      // Xóa các sản phẩm đã đặt khỏi giỏ hàng và làm mới dữ liệu tồn kho Trang chủ
      await _ref
          .read(cartControllerProvider.notifier)
          .removeSelectedItemsAfterOrder();
      _ref.invalidate(homeCatalogBundleProvider);

      // Sinh idempotencyKey mới cho phiên đặt hàng tiếp theo
      state = state.copyWith(
        isSubmitting: false,
        idempotencyKey: const Uuid().v4(),
      );
      return order;
    } on AppFailure catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.message,
      );
      return null;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Đặt hàng thất bại: $e',
      );
      return null;
    }
  }
}

final checkoutControllerProvider =
    StateNotifierProvider.autoDispose<CheckoutController, CheckoutSessionState>(
        (ref) {
  return CheckoutController(ref);
});
