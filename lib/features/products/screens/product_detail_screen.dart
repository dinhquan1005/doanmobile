import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_time_formatter.dart';
import '../../../core/widgets/product_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/storage_network_image.dart';
import '../../../data/models/product_model.dart';
import '../../cart/providers/cart_providers.dart';
import '../../favorites/providers/favorites_providers.dart';
import '../../home/providers/catalog_providers.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.productId,
  });

  final String productId;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  int _selectedImageIndex = 0;
  int _selectedQuantity = 1;

  void _shareProduct(ProductModel product) {
    final shareText =
        '${product.name} (${product.sku})\n'
        'Giá ưu đãi: ${CurrencyFormatter.formatVnd(product.effectivePrice)}\n'
        'Xem chi tiết tại: https://electronicstore.vn/products/${product.id}';
    Share.share(shareText);
  }

  Future<void> _handleAddToCart(ProductModel product) async {
    final success = await ref.read(cartControllerProvider.notifier).addProduct(
      productId: product.id,
      quantityToAdd: _selectedQuantity,
    );
    if (!mounted) {
      return;
    }
    final cartState = ref.read(cartControllerProvider);
    final message = success
        ? (cartState.infoMessage ?? 'Đã thêm vào giỏ hàng!')
        : (cartState.errorMessage ?? 'Không thể thêm vào giỏ hàng.');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: success
            ? SnackBarAction(
          label: 'Xem giỏ hàng',
          onPressed: () => context.go('/cart'),
        )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productDetailProvider(widget.productId));
    final reviewsAsync = ref.watch(productReviewsProvider(widget.productId));
    final isFavorite = ref.watch(isProductFavoriteProvider(widget.productId));
    final scheme = Theme.of(context).colorScheme;

    return productAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Chi tiết linh kiện')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text('Chi tiết linh kiện')),
        body: EmptyOrErrorState(
          icon: Icons.error_outline_rounded,
          title: 'Không thể tải thông tin sản phẩm',
          message: '$err',
          actionLabel: 'Thử lại',
          onAction: () =>
              ref.invalidate(productDetailProvider(widget.productId)),
        ),
      ),
      data: (product) {
        if (product == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Không tìm thấy')),
            body: EmptyOrErrorState(
              icon: Icons.inventory_2_outlined,
              title: 'Sản phẩm không tồn tại hoặc đã ngừng kinh doanh',
              message: 'Linh kiện này có thể đã bị ẩn hoặc xóa khỏi hệ thống.',
              actionLabel: 'Quay lại',
              onAction: () => context.pop(),
            ),
          );
        }

        final gallery = product.galleryImages;
        final relatedAsync = ref.watch(
          relatedProductsProvider(
            (categoryId: product.categoryId, excludeId: product.id),
          ),
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                key: const Key('toggle_favorite_detail_button'),
                tooltip: 'Yêu thích',
                onPressed: () async {
                  final added = await ref
                      .read(favoritesControllerProvider.notifier)
                      .toggleFavorite(product.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          added
                              ? 'Đã thêm vào danh sách yêu thích'
                              : 'Đã xóa khỏi danh sách yêu thích',
                        ),
                      ),
                    );
                  }
                },
                icon: Icon(
                  isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isFavorite ? Colors.redAccent : null,
                ),
              ),
              IconButton(
                tooltip: 'Chia sẻ liên kết sản phẩm',
                onPressed: () => _shareProduct(product),
                icon: const Icon(Icons.share_outlined),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(
                  top: BorderSide(color: scheme.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: scheme.outlineVariant),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _selectedQuantity > 1
                              ? () => setState(() => _selectedQuantity--)
                              : null,
                          icon: const Icon(Icons.remove_rounded, size: 18),
                        ),
                        Text(
                          '$_selectedQuantity',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        IconButton(
                          onPressed: _selectedQuantity < product.availableStock
                              ? () => setState(() => _selectedQuantity++)
                              : null,
                          icon: const Icon(Icons.add_rounded, size: 18),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('add_to_cart_detail_button'),
                      onPressed: product.inStock
                          ? () => _handleAddToCart(product)
                          : null,
                      icon: const Icon(Icons.add_shopping_cart_rounded),
                      label: Text(
                        product.inStock ? 'Thêm vào giỏ hàng' : 'Tạm hết hàng',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AspectRatio(
                aspectRatio: 1.15,
                child: StorageNetworkImage(
                  imageUrlOrPath: gallery.isNotEmpty
                      ? gallery[_selectedImageIndex.clamp(0, gallery.length - 1)]
                      : '',
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              if (gallery.length > 1) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 64,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: gallery.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final isSelected = idx == _selectedImageIndex;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedImageIndex = idx),
                        child: Container(
                          width: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? scheme.primary
                                  : scheme.outlineVariant,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: StorageNetworkImage(
                            imageUrlOrPath: gallery[idx],
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Chip(
                    label: Text(
                      'Thương hiệu: ${product.brandName}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(
                      'SKU: ${product.sku}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: product.inStock
                          ? AppColors.success.withValues(alpha: 0.14)
                          : AppColors.error.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      product.inStock
                          ? 'Còn hàng (${product.availableStock} sản phẩm)'
                          : 'Tạm hết hàng',
                      style: TextStyle(
                        color: product.inStock
                            ? AppColors.success
                            : AppColors.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                product.name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    '${product.ratingAvg.toStringAsFixed(1)} (${product.ratingCount} đánh giá)',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 16),
                  Text('Đã bán: ${product.soldCount}'),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.formatVnd(product.effectivePrice),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: scheme.primary,
                      ),
                    ),
                    if (product.hasDiscount) ...[
                      const SizedBox(width: 12),
                      Text(
                        CurrencyFormatter.formatVnd(product.price),
                        style: TextStyle(
                          fontSize: 14,
                          color: scheme.onSurfaceVariant,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.discountBadge,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '-${product.discountPercent}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: Icon(
                    Icons.verified_user_outlined,
                    color: scheme.primary,
                  ),
                  title: Text(
                    'Bảo hành chính hãng ${product.warrantyMonths} tháng',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(product.warrantyPolicy),
                ),
              ),
              const SizedBox(height: 16),
              if (product.specifications.isNotEmpty) ...[
                const Text(
                  'Thông số kỹ thuật',
                  style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: product.specifications.entries.map((entry) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color:
                              scheme.outlineVariant.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 135,
                              child: Text(
                                entry.key,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const Text(
                'Mô tả chi tiết sản phẩm',
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    product.description.isNotEmpty
                        ? product.description
                        : product.shortDescription,
                    style: const TextStyle(height: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Đánh giá & Nhận xét từ khách hàng',
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              reviewsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Không thể tải đánh giá: $e'),
                data: (reviews) {
                  if (reviews.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Chưa có đánh giá nào cho sản phẩm này. Hãy mua sản phẩm để trở thành người đầu tiên nhận xét!',
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: reviews.map((review) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      review.userName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    DateTimeFormatter.formatDate(
                                      review.createdAt,
                                    ),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: List.generate(5, (idx) {
                                  return Icon(
                                    idx < review.rating
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    color: Colors.amber,
                                    size: 16,
                                  );
                                }),
                              ),
                              const SizedBox(height: 6),
                              Text(review.comment),
                              if (review.adminReply != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Phản hồi từ Electronic Store: ${review.adminReply}',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
              relatedAsync.maybeWhen(
                data: (related) {
                  if (related.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sản phẩm liên quan cùng danh mục',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 285,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: related.length,
                          separatorBuilder: (_, __) =>
                          const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final item = related[index];
                            return SizedBox(
                              width: 178,
                              child: ProductCard(
                                product: item,
                                onTap: () =>
                                    context.push('/products/${item.id}'),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}