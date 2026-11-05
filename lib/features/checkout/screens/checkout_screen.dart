import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/storage_network_image.dart';
import '../../../data/models/address_model.dart';
import '../../cart/providers/cart_providers.dart';
import '../providers/checkout_providers.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _openAddressFormDialog({ShippingAddressModel? existing}) async {
    final result = await showDialog<ShippingAddressModel>(
      context: context,
      builder: (context) => _AddressFormDialog(initialAddress: existing),
    );
    if (result != null && mounted) {
      await ref.read(checkoutControllerProvider.notifier).saveAddress(result);
    }
  }

  Future<void> _handleConfirmOrder() async {
    final createdOrder = await ref
        .read(checkoutControllerProvider.notifier)
        .submitOrder(customerNote: _noteController.text);

    if (createdOrder != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đặt hàng thành công! Mã đơn: ${createdOrder.orderCode}',
          ),
        ),
      );
      context.go('/orders/${createdOrder.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartSummary = ref.watch(cartControllerProvider).summary;
    final checkoutState = ref.watch(checkoutControllerProvider);
    final addressesAsync = ref.watch(userAddressesStreamProvider);
    final scheme = Theme.of(context).colorScheme;

    final addresses =
        addressesAsync.valueOrNull ?? const <ShippingAddressModel>[];
    final activeAddress = checkoutState.selectedAddress ??
        (addresses.isNotEmpty ? addresses.first : null);

    if (checkoutState.selectedAddress == null && activeAddress != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(checkoutControllerProvider.notifier)
              .selectAddress(activeAddress);
        }
      });
    }

    if (cartSummary.selectedItems.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Xác nhận đặt hàng')),
        body: EmptyOrErrorState(
          icon: Icons.shopping_cart_checkout_rounded,
          title: 'Chưa có sản phẩm nào để thanh toán',
          message: 'Vui lòng quay lại giỏ hàng và chọn ít nhất 1 sản phẩm.',
          actionLabel: 'Quay lại giỏ hàng',
          onAction: () => context.go('/cart'),
        ),
      );
    }

    final subtotalAfterDiscount =
        cartSummary.subtotal - cartSummary.discountAmount;
    final shippingFee =
        checkoutState.calculateShippingFee(subtotalAfterDiscount);
    final finalTotal =
        (subtotalAfterDiscount + shippingFee).clamp(0, 999999999);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thanh toán & Đặt hàng'),
        leading: IconButton(
          key: const Key('checkout_back_button'),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Quay lại giỏ hàng',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/cart');
            }
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(top: BorderSide(color: scheme.outlineVariant)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tổng thanh toán:',
                      style: TextStyle(fontSize: 12.5),
                    ),
                    Text(
                      CurrencyFormatter.formatVnd(finalTotal),
                      key: const Key('checkout_final_total_text'),
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                key: const Key('confirm_place_order_button'),
                onPressed:
                    checkoutState.isSubmitting ? null : _handleConfirmOrder,
                icon: checkoutState.isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline_rounded),
                label: Text(
                  checkoutState.isSubmitting
                      ? 'Đang xử lý đơn...'
                      : 'Xác nhận đặt hàng',
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (checkoutState.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                checkoutState.errorMessage!,
                style: TextStyle(
                  color: scheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 1. Khu vực Địa chỉ nhận hàng (Thêm, Sửa, Xóa, Chọn)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, color: scheme.primary),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Địa chỉ nhận hàng',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        key: const Key('add_new_address_button'),
                        onPressed: () => _openAddressFormDialog(),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Thêm địa chỉ'),
                      ),
                    ],
                  ),
                  const Divider(),
                  if (addresses.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: OutlinedButton.icon(
                        onPressed: () => _openAddressFormDialog(),
                        icon: const Icon(Icons.add_location_alt_outlined),
                        label: const Text('Nhập địa chỉ nhận hàng mới'),
                      ),
                    )
                  else
                    ...addresses.map((addr) {
                      final isSelected = activeAddress?.id == addr.id;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () {
                          ref
                              .read(checkoutControllerProvider.notifier)
                              .selectAddress(addr);
                        },
                        leading: Icon(
                          isSelected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: isSelected
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                        title: Text(
                          '${addr.recipientName} • ${addr.phoneNumber}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                        subtitle: Text(
                          addr.fullAddressText,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Sửa địa chỉ',
                              onPressed: () =>
                                  _openAddressFormDialog(existing: addr),
                              icon: const Icon(Icons.edit_outlined, size: 20),
                            ),
                            IconButton(
                              tooltip: 'Xóa địa chỉ',
                              onPressed: () {
                                ref
                                    .read(checkoutControllerProvider.notifier)
                                    .deleteAddress(addr.id);
                              },
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                size: 20,
                                color: scheme.error,
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

          // 2. Phương thức giao hàng
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Phương thức giao hàng',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  _SelectableOptionTile(
                    isSelected: checkoutState.shippingMethod == 'standard',
                    title: 'Giao hàng tiêu chuẩn (2 - 4 ngày)',
                    subtitle:
                        'Miễn phí cho đơn hàng từ 2.000.000 ₫ (dưới 2 triệu phí 30.000 ₫)',
                    onTap: () {
                      ref
                          .read(checkoutControllerProvider.notifier)
                          .setShippingMethod('standard');
                    },
                  ),
                  _SelectableOptionTile(
                    isSelected: checkoutState.shippingMethod == 'express',
                    title: 'Giao hàng hỏa tốc nội thành (60.000 ₫)',
                    subtitle: 'Nhận linh kiện nhanh trong ngày',
                    onTap: () {
                      ref
                          .read(checkoutControllerProvider.notifier)
                          .setShippingMethod('express');
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 3. Phương thức thanh toán
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Phương thức thanh toán',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  _SelectableOptionTile(
                    isSelected: checkoutState.paymentMethod == 'COD',
                    title: 'Thanh toán khi nhận hàng (COD)',
                    subtitle:
                        'Kiểm tra ngoại quan linh kiện và thanh toán tiền mặt cho bưu tá',
                    onTap: () {
                      ref
                          .read(checkoutControllerProvider.notifier)
                          .setPaymentMethod('COD');
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 4. Danh sách sản phẩm đặt mua & Ghi chú
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sản phẩm đặt mua (${cartSummary.selectedItems.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Divider(height: 18),
                  ...cartSummary.selectedItems.map((item) {
                    final p = item.product;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 52,
                            height: 52,
                            child: StorageNetworkImage(
                              imageUrlOrPath: p?.thumbnailUrl ?? '',
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p?.name ?? item.productId,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${CurrencyFormatter.formatVnd(item.latestUnitPrice)} x ${item.quantity}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            CurrencyFormatter.formatVnd(item.lineSubtotal),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('checkout_note_input'),
                    controller: _noteController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú cho đơn hàng (tùy chọn)',
                      hintText:
                          'Ví dụ: Giao giờ hành chính, xuất hóa đơn VAT...',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 5. Chi tiết thanh toán
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tạm tính:'),
                      Text(
                        CurrencyFormatter.formatVnd(cartSummary.subtotal),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        cartSummary.appliedCoupon != null
                            ? 'Giảm giá (${cartSummary.appliedCoupon!.code}):'
                            : 'Giảm giá khuyến mãi:',
                      ),
                      Text(
                        '-${CurrencyFormatter.formatVnd(cartSummary.discountAmount)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Phí giao hàng:'),
                      Text(
                        shippingFee == 0
                            ? 'Miễn phí'
                            : CurrencyFormatter.formatVnd(shippingFee),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SelectableOptionTile extends StatelessWidget {
  const _SelectableOptionTile({
    required this.isSelected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool isSelected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Icon(
        isSelected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_off_rounded,
        color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12.5),
      ),
    );
  }
}

class _AddressFormDialog extends StatefulWidget {
  const _AddressFormDialog({this.initialAddress});

  final ShippingAddressModel? initialAddress;

  @override
  State<_AddressFormDialog> createState() => _AddressFormDialogState();
}

class _AddressFormDialogState extends State<_AddressFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _provinceCtrl;
  late final TextEditingController _districtCtrl;
  late final TextEditingController _wardCtrl;
  late final TextEditingController _streetCtrl;
  bool _isDefault = true;

  @override
  void initState() {
    super.initState();
    final a = widget.initialAddress;
    _nameCtrl = TextEditingController(text: a?.recipientName ?? '');
    _phoneCtrl = TextEditingController(text: a?.phoneNumber ?? '');
    _provinceCtrl =
        TextEditingController(text: a?.province ?? 'TP. Hồ Chí Minh');
    _districtCtrl = TextEditingController(text: a?.district ?? '');
    _wardCtrl = TextEditingController(text: a?.ward ?? '');
    _streetCtrl = TextEditingController(text: a?.streetAddress ?? '');
    _isDefault = a?.isDefault ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _provinceCtrl.dispose();
    _districtCtrl.dispose();
    _wardCtrl.dispose();
    _streetCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final model = ShippingAddressModel(
      id: widget.initialAddress?.id ?? '',
      recipientName: _nameCtrl.text.trim(),
      phoneNumber: _phoneCtrl.text.trim(),
      province: _provinceCtrl.text.trim(),
      district: _districtCtrl.text.trim(),
      ward: _wardCtrl.text.trim(),
      streetAddress: _streetCtrl.text.trim(),
      isDefault: _isDefault,
    );
    Navigator.of(context).pop(model);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initialAddress == null
            ? 'Thêm địa chỉ nhận hàng'
            : 'Cập nhật địa chỉ',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration:
                    const InputDecoration(labelText: 'Họ tên người nhận'),
                validator: (v) =>
                    AppValidators.validateRequired(v, fieldName: 'họ tên'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Số điện thoại'),
                validator: AppValidators.validateVietnamPhone,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _provinceCtrl,
                decoration:
                    const InputDecoration(labelText: 'Tỉnh / Thành phố'),
                validator: (v) => AppValidators.validateRequired(
                  v,
                  fieldName: 'tỉnh/thành phố',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _districtCtrl,
                decoration: const InputDecoration(labelText: 'Quận / Huyện'),
                validator: (v) =>
                    AppValidators.validateRequired(v, fieldName: 'quận/huyện'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _wardCtrl,
                decoration: const InputDecoration(labelText: 'Phường / Xã'),
                validator: (v) =>
                    AppValidators.validateRequired(v, fieldName: 'phường/xã'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _streetCtrl,
                decoration:
                    const InputDecoration(labelText: 'Số nhà, tên đường'),
                validator: (v) => AppValidators.validateRequired(
                  v,
                  fieldName: 'số nhà, tên đường',
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v ?? true),
                title: const Text('Đặt làm địa chỉ mặc định'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Lưu địa chỉ'),
        ),
      ],
    );
  }
}
