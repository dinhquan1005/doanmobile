import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/storage_network_image.dart';
import '../../../data/models/product_model.dart';
import '../../home/providers/catalog_providers.dart';
import 'admin_product_form_screen.dart';

/// Provider cung cấp số liệu thống kê nhanh cho trang Admin
final adminDashboardStatsProvider = FutureProvider.autoDispose<AdminStats>((ref) async {
  final firestore = ref.watch(firestoreProvider);

  // Truy vấn số lượng tài liệu từ các collections chính
  final productsSnap = await firestore.collection(FirestoreCollections.products).get();
  final ordersSnap = await firestore.collection(FirestoreCollections.orders).get();
  final categoriesSnap = await firestore.collection(FirestoreCollections.categories).get();

  final products = productsSnap.docs.map(ProductModel.fromFirestore).toList(growable: false);
  final lowStockCount = products.where((p) => p.stockQuantity > 0 && p.stockQuantity <= 5).length;
  final outOfStockCount = products.where((p) => p.stockQuantity <= 0).length;

  return AdminStats(
    totalProducts: products.length,
    lowStockCount: lowStockCount,
    outOfStockCount: outOfStockCount,
    totalOrders: ordersSnap.docs.length,
    totalCategories: categoriesSnap.docs.length,
    products: products,
  );
});

class AdminStats {
  const AdminStats({
    required this.totalProducts,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.totalOrders,
    required this.totalCategories,
    required this.products,
  });

  final int totalProducts;
  final int lowStockCount;
  final int outOfStockCount;
  final int totalOrders;
  final int totalCategories;
  final List<ProductModel> products;
}

/// Màn hình Quản trị viên (Admin Panel) được thiết kế tinh gọn,
/// trực quan và dễ tiếp cận cho người mới học lập trình Flutter & Firebase.
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  bool _isSeeding = false;

  Future<void> _handleSeedData() async {
    setState(() => _isSeeding = true);
    try {
      await ref.read(catalogSeedServiceProvider).seedInitialCatalogToFirestore();
      ref.invalidate(adminDashboardStatsProvider);
      ref.invalidate(homeCatalogBundleProvider);
      ref.invalidate(categoriesListProvider);
      ref.invalidate(brandsListProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Khởi tạo thành công toàn bộ dữ liệu mẫu lên Cloud Firestore!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.error,
            content: Text('Lỗi khi nạp dữ liệu: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSeeding = false);
      }
    }
  }

  Future<void> _confirmDeleteProduct(ProductModel product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa linh kiện'),
        content: Text(
          'Bạn có chắc chắn muốn xóa sản phẩm "${product.name}" khỏi hệ thống không?\nHành động này sẽ cập nhật kho và xóa khỏi danh sách sản phẩm.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref
            .read(catalogRepositoryProvider)
            .deleteProduct(product.id, permanent: true);
        ref.invalidate(adminDashboardStatsProvider);
        ref.invalidate(homeCatalogBundleProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Text('Đã xóa thành công linh kiện: ${product.name}'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Theme.of(context).colorScheme.error,
              content: Text('Lỗi khi xóa sản phẩm: $e'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(adminDashboardStatsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảng quản trị (Admin Dashboard)'),
        actions: [
          IconButton(
            tooltip: 'Làm mới số liệu',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(adminDashboardStatsProvider),
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => EmptyOrErrorState(
          icon: Icons.error_outline_rounded,
          title: 'Không thể tải dữ liệu quản trị',
          message: '$err',
          actionLabel: 'Thử lại',
          onAction: () => ref.invalidate(adminDashboardStatsProvider),
        ),
        data: (stats) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(adminDashboardStatsProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Khối thông tin định hướng học tập
                Card(
                  color: scheme.primaryContainer.withValues(alpha: 0.3),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: scheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.dashboard_customize_rounded, color: scheme.primary, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Trung tâm quản trị cửa hàng:',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: scheme.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Hệ thống quản lý kho hàng, phân loại danh mục sản phẩm, theo dõi tình trạng đơn đặt hàng và cấu hình chương trình ưu đãi thời gian thực.',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Lưới 4 thẻ thống kê nhanh (KPI Cards)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.45,
                      children: [
                        _StatCard(
                          title: 'Sản phẩm',
                          value: '${stats.totalProducts}',
                          icon: Icons.inventory_2_rounded,
                          color: Colors.blue,
                        ),
                        _StatCard(
                          title: 'Đơn hàng',
                          value: '${stats.totalOrders}',
                          icon: Icons.receipt_long_rounded,
                          color: Colors.green,
                        ),
                        _StatCard(
                          title: 'Danh mục',
                          value: '${stats.totalCategories}',
                          icon: Icons.category_rounded,
                          color: Colors.orange,
                        ),
                        _StatCard(
                          title: 'Cần bổ sung',
                          value: '${stats.lowStockCount + stats.outOfStockCount}',
                          icon: Icons.warning_amber_rounded,
                          color: Colors.redAccent,
                          subtitle: stats.outOfStockCount > 0
                              ? 'Hết: ${stats.outOfStockCount}'
                              : null,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Thao tác nhanh quản trị: Nút Nạp dữ liệu mẫu
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Công cụ dữ liệu (Catalog Data Tool)',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Nạp toàn bộ danh mục linh kiện (CPU, GPU, RAM, Arduino), các thương hiệu nổi tiếng, banner và mã giảm giá mẫu vào Cloud Firestore.',
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          key: const Key('admin_seed_data_button'),
                          onPressed: _isSeeding ? null : _handleSeedData,
                          icon: _isSeeding
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.cloud_upload_rounded),
                          label: Text(
                            _isSeeding ? 'Đang khởi tạo dữ liệu...' : 'Khởi tạo danh mục & dữ liệu gốc',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Danh sách theo dõi tồn kho nhanh (Inventory Monitor)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Theo dõi tồn kho linh kiện (${stats.products.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    FilledButton.tonalIcon(
                      key: const Key('admin_add_product_button'),
                      onPressed: () async {
                        final added = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (context) => const AdminProductFormScreen(),
                          ),
                        );
                        if (added == true) {
                          ref.invalidate(adminDashboardStatsProvider);
                        }
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Thêm linh kiện'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (stats.products.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'Chưa có linh kiện nào trong kho. Hãy nhấn nút "Khởi tạo danh mục & dữ liệu gốc" hoặc "Thêm linh kiện" để bắt đầu!',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  )
                else
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: stats.products.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final product = stats.products[index];
                        final isOut = product.stockQuantity <= 0;
                        final isLow = product.stockQuantity > 0 && product.stockQuantity <= 5;

                        Color statusColor = Colors.green;
                        String statusLabel = 'Còn ${product.stockQuantity}';

                        if (isOut) {
                          statusColor = Colors.red;
                          statusLabel = 'Hết hàng';
                        } else if (isLow) {
                          statusColor = Colors.orange;
                          statusLabel = 'Sắp hết (${product.stockQuantity})';
                        }

                        return ListTile(
                          leading: SizedBox(
                            width: 44,
                            height: 44,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: StorageNetworkImage(
                                imageUrlOrPath: product.thumbnailUrl,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          title: Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'SKU: ${product.sku} • ${CurrencyFormatter.formatVnd(product.effectivePrice)}',
                            style: theme.textTheme.bodySmall,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Chip(
                                label: Text(
                                  statusLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                                backgroundColor: statusColor.withValues(alpha: 0.12),
                                side: BorderSide(color: statusColor.withValues(alpha: 0.3)),
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded, size: 20),
                                tooltip: 'Tùy chọn thao tác',
                                onSelected: (action) async {
                                  if (action == 'edit') {
                                    final updated = await Navigator.of(context).push<bool>(
                                      MaterialPageRoute(
                                        builder: (context) => AdminProductFormScreen(
                                          initialProduct: product,
                                        ),
                                      ),
                                    );
                                    if (updated == true) {
                                      ref.invalidate(adminDashboardStatsProvider);
                                    }
                                  } else if (action == 'view') {
                                    await context.push('/products/${product.id}');
                                  } else if (action == 'delete') {
                                    await _confirmDeleteProduct(product);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'view',
                                    child: Row(
                                      children: [
                                        Icon(Icons.visibility_outlined, size: 18),
                                        SizedBox(width: 8),
                                        Text('Xem trang sản phẩm'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                                        SizedBox(width: 8),
                                        Text('Chỉnh sửa thông tin'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Xóa linh kiện', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          onTap: () => context.push('/products/${product.id}'),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 72),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('admin_add_product_fab'),
        onPressed: () async {
          final added = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (context) => const AdminProductFormScreen(),
            ),
          );
          if (added == true) {
            ref.invalidate(adminDashboardStatsProvider);
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm linh kiện mới'),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(icon, size: 18, color: color),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
