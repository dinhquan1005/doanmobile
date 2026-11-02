import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/storage_network_image.dart';
import '../../../data/models/cart_model.dart';
import '../../home/providers/catalog_providers.dart';
import '../providers/cart_providers.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final TextEditingController _couponController = TextEditingController();

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _handleApplyCoupon() async {
    final code = _couponController.text.trim();
    final success =
        await ref.read(cartControllerProvider.notifier).applyCouponCode(code);
    if (success && mounted) {
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartControllerProvider);
    final summary = cartState.summary;
    final scheme = Theme.of(context).colorScheme;
    final activeCoupons =
        ref.watch(homeCatalogBundleProvider).valueOrNull?.activeCoupons ?? [];
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWideLayout = screenWidth >= 700;

    return Scaffold(
      appBar: AppBar(
        title: Text('Giỏ hàng (${summary.totalItemCount})'),
        actions: [
          IconButton(
            tooltip: 'Cập nhật giá & tồn kho mới nhất',
            onPressed: () {
              ref
                  .read(cartControllerProvider.notifier)
                  .refreshLatestPricesAndStock();
            },
            icon: const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (cartState.isLoading && summary.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (summary.items.isEmpty) {
            return EmptyOrErrorState(
              icon: Icons.remove_shopping_cart_outlined,
              title: 'Giỏ hàng của bạn đang trống',
              message:
                  'Hãy khám phá các dòng CPU, Card đồ họa, RAM, SSD và linh kiện DIY chính hãng để thêm vào giỏ hàng.',
              actionLabel: 'Khám phá sản phẩm ngay',
              onAction: () => context.push('/search'),
            );
          }

          final itemsListWidget = Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  border: Border(
                    bottom: BorderSide(color: scheme.outlineVariant),
                  ),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      key: const Key('cart_select_all_checkbox'),
                      value: summary.isAllSelected,
                      onChanged: (val) {
                        ref
                            .read(cartControllerProvider.notifier)
                            .toggleSelectAll(val ?? false);
                      },
                    ),
                    Expanded(
                      child: Text(
                        'Chọn tất cả (${summary.items.length} sản phẩm)',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      'Đã chọn: ${summary.selectedItems.length}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (cartState.errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: scheme.errorContainer,
                  child: Text(
                    cartState.errorMessage!,
                    style: TextStyle(
                      color: scheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => ref
                      .read(cartControllerProvider.notifier)
                      .refreshLatestPricesAndStock(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: summary.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = summary.items[index];
                      return _CartItemTile(item: item);
                    },
                  ),
                ),
              ),
            ],
          );

          final summaryBox = _CartSummaryPanel(
            summary: summary,
            couponController: _couponController,
            isApplyingCoupon: cartState.isApplyingCoupon,
            onApplyCoupon: _handleApplyCoupon,
            onRemoveCoupon: () {
              _couponController.clear();
              ref.read(cartControllerProvider.notifier).removeCoupon();
            },
            onSelectQuickCoupon: (code) {
              _couponController.text = code;
              _handleApplyCoupon();
            },
            quickCouponCodes: activeCoupons
                .map((c) => c.code)
                .take(3)
                .toList(growable: false),
          );

          if (isWideLayout) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: itemsListWidget),
                VerticalDivider(width: 1, color: scheme.outlineVariant),
                SizedBox(
                  width: screenWidth >= 1000 ? 380 : 340,
                  child: Container(
                    color: scheme.surface,
                    child: SingleChildScrollView(
                      child: summaryBox,
                    ),
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              Expanded(child: itemsListWidget),
              summaryBox,
            ],
          );
        },
      ),
    );
  }
}

class _CartItemTile extends ConsumerWidget {
  const _CartItemTile({required this.item});

  final ResolvedCartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final product = item.product;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: item.isSelected,
                  onChanged: (val) {
                    ref
                        .read(cartControllerProvider.notifier)
                        .toggleSelectItem(item.productId, val ?? false);
                  },
                ),
                GestureDetector(
                  onTap: product != null
                      ? () => context.push('/products/${product.id}')
                      : null,
                  child: SizedBox(
                    width: 68,
                    height: 68,
                    child: StorageNetworkImage(
                      imageUrlOrPath: product?.thumbnailUrl ?? '',
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product?.name ?? 'Sản phẩm (${item.productId})',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (product != null)
                        Text(
                          'SKU: ${product.sku} • Kho: ${product.availableStock}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        children: [
                          Text(
                            CurrencyFormatter.formatVnd(item.latestUnitPrice),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: scheme.primary,
                            ),
                          ),
                          if (product != null && product.hasDiscount)
                            Text(
                              CurrencyFormatter.formatVnd(product.price),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: scheme.onSurfaceVariant,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: Key('remove_cart_item_${item.productId}'),
                  tooltip: 'Xóa khỏi giỏ hàng',
                  onPressed: () {
                    ref
                        .read(cartControllerProvider.notifier)
                        .removeItem(item.productId);
                  },
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: scheme.error,
                  ),
                ),
              ],
            ),
            if (item.stockWarningMessage != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.stockWarningMessage!,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const Divider(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Thành tiền: ${CurrencyFormatter.formatVnd(item.lineSubtotal)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: scheme.outlineVariant),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: Key('decrease_qty_${item.productId}'),
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          ref
                              .read(cartControllerProvider.notifier)
                              .updateQuantity(
                                productId: item.productId,
                                newQuantity: item.quantity - 1,
                              );
                        },
                        icon: const Icon(Icons.remove_rounded, size: 18),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '${item.quantity}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        key: Key('increase_qty_${item.productId}'),
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: item.isOutOfStock ||
                                (item.availableStock > 0 &&
                                    item.quantity >= item.availableStock)
                            ? null
                            : () {
                                ref
                                    .read(cartControllerProvider.notifier)
                                    .updateQuantity(
                                      productId: item.productId,
                                      newQuantity: item.quantity + 1,
                                    );
                              },
                        icon: const Icon(Icons.add_rounded, size: 18),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CartSummaryPanel extends StatelessWidget {
  const _CartSummaryPanel({
    required this.summary,
    required this.couponController,
    required this.isApplyingCoupon,
    required this.onApplyCoupon,
    required this.onRemoveCoupon,
    required this.onSelectQuickCoupon,
    required this.quickCouponCodes,
  });

  final CartSummary summary;
  final TextEditingController couponController;
  final bool isApplyingCoupon;
  final VoidCallback onApplyCoupon;
  final VoidCallback onRemoveCoupon;
  final ValueChanged<String> onSelectQuickCoupon;
  final List<String> quickCouponCodes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Thanh toán & Khuyến mãi',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 10),
            if (summary.appliedCoupon != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_offer_rounded,
                      size: 18,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mã ${summary.appliedCoupon!.code} (-${CurrencyFormatter.formatVnd(summary.discountAmount)})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onRemoveCoupon,
                      child: const Text('Bỏ mã'),
                    ),
                  ],
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: TextField(
                        key: const Key('cart_coupon_input'),
                        controller: couponController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          hintText: 'Mã giảm giá (VD: LINHKIEN150K)',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    key: const Key('cart_apply_coupon_button'),
                    onPressed: isApplyingCoupon ? null : onApplyCoupon,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(72, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text('Áp dụng'),
                  ),
                ],
              ),
              if (quickCouponCodes.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: quickCouponCodes.map((code) {
                    return ActionChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        code,
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      onPressed: () => onSelectQuickCoupon(code),
                    );
                  }).toList(),
                ),
              ],
            ],
            const Divider(height: 18),
            _SummaryRow(
              label: 'Tạm tính (${summary.selectedItems.length} món):',
              value: CurrencyFormatter.formatVnd(summary.subtotal),
            ),
            if (summary.discountAmount > 0)
              _SummaryRow(
                label: 'Giảm giá:',
                value: '-${CurrencyFormatter.formatVnd(summary.discountAmount)}',
                valueColor: AppColors.success,
              ),
            _SummaryRow(
              label: 'Phí giao hàng (dự kiến):',
              value: summary.estimatedShippingFee == 0 && summary.subtotal > 0
                  ? 'Miễn phí'
                  : CurrencyFormatter.formatVnd(summary.estimatedShippingFee),
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Tổng tạm tính:',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  CurrencyFormatter.formatVnd(summary.estimatedTotal),
                  key: const Key('cart_estimated_total_text'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('proceed_to_checkout_button'),
              onPressed: summary.canProceedToCheckout
                  ? () => context.push('/checkout')
                  : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.payment_rounded),
              label: const Text('Tiến hành đặt hàng'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
