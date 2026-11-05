import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_time_formatter.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/storage_network_image.dart';
import '../../../data/models/order_model.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/orders_providers.dart';

final selectedOrderStatusFilterProvider = StateProvider<OrderStatus?>((ref) {
  return null;
});

final filteredUserOrdersProvider =
    Provider<AsyncValue<List<OrderModel>>>((ref) {
  final ordersAsync = ref.watch(userOrdersStreamProvider);
  final statusFilter = ref.watch(selectedOrderStatusFilterProvider);

  return ordersAsync.whenData((orders) {
    if (statusFilter == null) {
      return orders;
    }
    return orders
        .where((order) => order.status == statusFilter)
        .toList(growable: false);
  });
});

class OrdersListScreen extends ConsumerWidget {
  const OrdersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authStateChangesProvider).valueOrNull;
    final selectedStatus = ref.watch(selectedOrderStatusFilterProvider);
    final ordersAsync = ref.watch(filteredUserOrdersProvider);
    final scheme = Theme.of(context).colorScheme;

    if (authUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Đơn hàng của tôi'),
        ),
        body: EmptyOrErrorState(
          icon: Icons.lock_person_outlined,
          title: 'Vui lòng đăng nhập để xem đơn hàng',
          message:
              'Đăng nhập tài khoản để theo dõi trạng thái giao hàng, lịch sử mua sắm và thời hạn bảo hành linh kiện.',
          actionLabel: 'Đăng nhập ngay',
          onAction: () => context.push('/login'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đơn hàng của tôi'),
      ),
      body: Column(
        children: [
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(
                bottom: BorderSide(color: scheme.outlineVariant),
              ),
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: const Key('order_filter_all'),
                    label: const Text('Tất cả'),
                    selected: selectedStatus == null,
                    onSelected: (_) {
                      ref
                          .read(selectedOrderStatusFilterProvider.notifier)
                          .state = null;
                    },
                  ),
                ),
                ...OrderStatus.values.map((status) {
                  final isSelected = selectedStatus == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: Key('order_filter_${status.code}'),
                      label: Text(status.labelVi),
                      selected: isSelected,
                      onSelected: (_) {
                        ref
                            .read(selectedOrderStatusFilterProvider.notifier)
                            .state = isSelected ? null : status;
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          Expanded(
            child: ordersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => EmptyOrErrorState(
                icon: Icons.error_outline_rounded,
                title: 'Không thể tải danh sách đơn hàng',
                message: '$err',
                actionLabel: 'Thử lại',
                onAction: () => ref.invalidate(userOrdersStreamProvider),
              ),
              data: (orders) {
                if (orders.isEmpty) {
                  return EmptyOrErrorState(
                    icon: Icons.receipt_long_outlined,
                    title: selectedStatus == null
                        ? 'Bạn chưa có đơn hàng nào'
                        : 'Không có đơn hàng ở trạng thái "${selectedStatus.labelVi}"',
                    message:
                        'Khi bạn đặt mua linh kiện, mọi thông tin vận chuyển và bảo hành sẽ hiển thị tại đây.',
                    actionLabel: 'Mua sắm ngay',
                    onAction: () => context.go('/'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return _OrderSummaryCard(
                      order: order,
                      onTap: () => context.push('/orders/${order.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({
    required this.order,
    required this.onTap,
  });

  final OrderModel order;
  final VoidCallback onTap;

  Color _statusColor(OrderStatus status) {
    return switch (status) {
      OrderStatus.pendingConfirmation => AppColors.warning,
      OrderStatus.confirmed ||
      OrderStatus.preparing ||
      OrderStatus.shipping =>
        AppColors.electricBlue,
      OrderStatus.delivered => AppColors.success,
      OrderStatus.cancelled || OrderStatus.refunded => AppColors.error,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final firstItem = order.items.isNotEmpty ? order.items.first : null;
    final statusBadgeColor = _statusColor(order.status);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('order_card_${order.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    size: 18,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      order.orderCode,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusBadgeColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      order.status.labelVi,
                      style: TextStyle(
                        color: statusBadgeColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Ngày đặt: ${DateTimeFormatter.formatDateTime(order.createdAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Divider(height: 18),
              if (firstItem != null)
                Row(
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: StorageNetworkImage(
                        imageUrlOrPath: firstItem.thumbnailUrl,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            firstItem.productName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'SKU: ${firstItem.sku} • SL: x${firstItem.quantity}',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            CurrencyFormatter.formatVnd(
                              firstItem.finalUnitPrice,
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              if (order.items.length > 1) ...[
                const SizedBox(height: 8),
                Text(
                  '+ ${order.items.length - 1} sản phẩm linh kiện khác trong đơn',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: scheme.secondary,
                  ),
                ),
              ],
              const Divider(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Thanh toán: ${order.paymentMethod}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    children: [
                      const Text(
                        'Tổng tiền: ',
                        style: TextStyle(fontSize: 13),
                      ),
                      Text(
                        CurrencyFormatter.formatVnd(order.totalAmount),
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
