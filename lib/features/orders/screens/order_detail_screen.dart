import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_time_formatter.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/storage_network_image.dart';
import '../../../data/models/order_model.dart';
import '../providers/orders_providers.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({
    super.key,
    required this.orderId,
  });

  final String orderId;

  Future<void> _showCancelOrderDialog(
    BuildContext context,
    WidgetRef ref,
    OrderModel order,
  ) async {
    final reasonController = TextEditingController(
      text: 'Thay đổi nhu cầu cấu hình linh kiện',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Xác nhận hủy đơn hàng'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bạn có chắc muốn hủy đơn hàng ${order.orderCode}? Số lượng linh kiện sẽ được hoàn trả lại kho.',
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('cancel_order_reason_input'),
                controller: reasonController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Lý do hủy đơn',
                  hintText: 'Nhập lý do hủy đơn hàng...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Đóng'),
            ),
            FilledButton(
              key: const Key('confirm_cancel_order_button'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Xác nhận hủy'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      reasonController.dispose();
      return;
    }

    final reason = reasonController.text.trim().isNotEmpty
        ? reasonController.text.trim()
        : 'Khách hàng yêu cầu hủy đơn';
    reasonController.dispose();

    final success = await ref
        .read(orderActionControllerProvider.notifier)
        .cancelOrder(orderId: order.id, reason: reason);

    if (!context.mounted) {
      return;
    }
    final actionState = ref.read(orderActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (actionState.infoMessage ?? 'Đã hủy đơn hàng thành công.')
              : (actionState.errorMessage ?? 'Không thể hủy đơn hàng.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailStreamProvider(orderId));
    final actionState = ref.watch(orderActionControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết đơn hàng'),
        leading: IconButton(
          key: const Key('order_detail_back_button'),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Quay lại',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/orders');
            }
          },
        ),
        actions: [
          IconButton(
            key: const Key('order_detail_home_button'),
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Trang chủ',
            onPressed: () => context.go('/'),
          ),
        ],
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => EmptyOrErrorState(
          icon: Icons.error_outline_rounded,
          title: 'Không thể tải thông tin đơn hàng',
          message: '$err',
          actionLabel: 'Thử lại',
          onAction: () => ref.invalidate(orderDetailStreamProvider(orderId)),
        ),
        data: (order) {
          if (order == null) {
            return EmptyOrErrorState(
              icon: Icons.receipt_long_outlined,
              title: 'Đơn hàng không tồn tại',
              message: 'Không tìm thấy dữ liệu cho mã đơn hàng này.',
              actionLabel: 'Quay lại danh sách',
              onAction: () => context.go('/orders'),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Mã đơn: ${order.orderCode}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Chip(
                            label: Text(
                              order.status.labelVi,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Thời gian đặt: ${DateTimeFormatter.formatDateTime(order.createdAt)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Phương thức thanh toán: ${order.paymentMethod} (${order.paymentStatus.toUpperCase()})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (order.cancelReason != null &&
                          order.cancelReason!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Lý do hủy: ${order.cancelReason}',
                            style: const TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            color: scheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Địa chỉ nhận hàng (Bản chụp đơn hàng)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 18),
                      Text(
                        '${order.shippingAddress.recipientName} •${order.shippingAddress.phoneNumber}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order.shippingAddress.fullAddressText,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      if (order.customerNote != null &&
                          order.customerNote!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Ghi chú giao hàng: "${order.customerNote}"',
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Linh kiện đã đặt (${order.items.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const Divider(height: 18),
                      ...order.items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 64,
                                height: 64,
                                child: StorageNetworkImage(
                                  imageUrlOrPath: item.thumbnailUrl,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.productName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'SKU: ${item.sku} • Bảo hành: ${item.warrantyMonths} tháng',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${CurrencyFormatter.formatVnd(item.finalUnitPrice)} x${item.quantity}',
                                          style: const TextStyle(fontSize: 12.5),
                                        ),
                                        Text(
                                          CurrencyFormatter.formatVnd(
                                            item.lineTotal,
                                          ),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: scheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _PriceRow(
                        label: 'Tạm tính:',
                        value: CurrencyFormatter.formatVnd(order.subtotal),
                      ),
                      const SizedBox(height: 6),
                      _PriceRow(
                        label: order.couponCode != null
                            ? 'Giảm giá (${order.couponCode}):'
                            : 'Giảm giá:',
                        value:
                            '-${CurrencyFormatter.formatVnd(order.discountAmount)}',
                        valueColor: AppColors.success,
                      ),
                      const SizedBox(height: 6),
                      _PriceRow(
                        label:
                            'Phí vận chuyển (${order.shippingMethod == "express" ? "Hỏa tốc" : "Tiêu chuẩn"}):',
                        value: order.shippingFee == 0
                            ? 'Miễn phí'
                            : CurrencyFormatter.formatVnd(order.shippingFee),
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Tổng thanh toán:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.formatVnd(order.totalAmount),
                            key: const Key('order_detail_total_amount'),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: scheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lịch sử trạng thái đơn hàng',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const Divider(height: 18),
                      ...order.statusHistory.reversed.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      OrderStatus.fromCode(
                                        entry.status,
                                      ).labelVi,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    if (entry.note.isNotEmpty)
                                      Text(
                                        entry.note,
                                        style: const TextStyle(fontSize: 12.5),
                                      ),
                                    Text(
                                      DateTimeFormatter.formatDateTime(
                                        entry.changedAt,
                                      ),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              if (order.canCustomerCancel) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  key: const Key('cancel_order_button'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: actionState.isCancelling
                      ? null
                      : () => _showCancelOrderDialog(context, ref, order),
                  icon: const Icon(Icons.cancel_outlined),
                  label: Text(
                    actionState.isCancelling
                        ? 'Đang xử lý hủy đơn...'
                        : 'Hủy đơn hàng & Hoàn kho',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('order_detail_view_orders_button'),
                      onPressed: () => context.go('/orders'),
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: const Text('Xem đơn hàng'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('order_detail_continue_shopping_button'),
                      onPressed: () => context.go('/'),
                      icon: const Icon(Icons.shopping_bag_outlined),
                      label: const Text('Tiếp tục mua sắm'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
