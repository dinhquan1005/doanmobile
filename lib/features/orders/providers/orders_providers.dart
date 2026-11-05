import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_failure.dart';
import '../../../data/models/order_model.dart';
import '../../auth/providers/auth_providers.dart';
import '../../checkout/providers/checkout_providers.dart';
import '../../home/providers/catalog_providers.dart';

final userOrdersStreamProvider = StreamProvider<List<OrderModel>>((ref) {
  final user = ref.watch(authStateChangesProvider).valueOrNull;
  if (user == null) {
    return Stream.value(const <OrderModel>[]);
  }
  return ref.watch(orderRepositoryProvider).watchUserOrders(user.uid);
});

final orderDetailStreamProvider =
    StreamProvider.family<OrderModel?, String>((ref, orderId) {
  return ref.watch(orderRepositoryProvider).watchOrderById(orderId);
});

class OrderActionState {
  const OrderActionState({
    this.isCancelling = false,
    this.errorMessage,
    this.infoMessage,
  });

  final bool isCancelling;
  final String? errorMessage;
  final String? infoMessage;
}

class OrderActionController extends StateNotifier<OrderActionState> {
  OrderActionController(this._ref) : super(const OrderActionState());

  final Ref _ref;

  Future<bool> cancelOrder({
    required String orderId,
    required String reason,
  }) async {
    final user = _ref.read(currentUserProfileProvider).valueOrNull;
    if (user == null) {
      state = const OrderActionState(
        errorMessage: 'Vui lòng đăng nhập để thực hiện thao tác này.',
      );
      return false;
    }

    state = const OrderActionState(isCancelling: true);
    try {
      await _ref.read(orderRepositoryProvider).cancelOrderAndRestoreStock(
            orderId: orderId,
            userId: user.id,
            reason: reason,
            isAdminOrStaff: user.isStaffOrAdmin,
          );
      _ref.invalidate(homeCatalogBundleProvider);
      state = const OrderActionState(
        isCancelling: false,
        infoMessage: 'Đã hủy đơn hàng và hoàn lại tồn kho thành công.',
      );
      return true;
    } on AppFailure catch (e) {
      state = OrderActionState(
        isCancelling: false,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = OrderActionState(
        isCancelling: false,
        errorMessage: 'Không thể hủy đơn hàng: $e',
      );
      return false;
    }
  }
}

final orderActionControllerProvider =
    StateNotifierProvider<OrderActionController, OrderActionState>((ref) {
  return OrderActionController(ref);
});
