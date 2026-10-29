import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/product_card.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../../../core/widgets/state_views.dart';
import '../providers/favorites_providers.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteProductsAsync = ref.watch(favoriteProductsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sản phẩm yêu thích'),
      ),
      body: favoriteProductsAsync.when(
        loading: () => const SingleChildScrollView(
          child: ProductGridSkeleton(itemCount: 4),
        ),
        error: (err, _) => EmptyOrErrorState(
          icon: Icons.error_outline_rounded,
          title: 'Không thể tải danh sách yêu thích',
          message: '$err',
          actionLabel: 'Thử lại',
          onAction: () => ref.invalidate(favoriteProductsListProvider),
        ),
        data: (products) {
          if (products.isEmpty) {
            return EmptyOrErrorState(
              icon: Icons.favorite_border_rounded,
              title: 'Chưa có linh kiện yêu thích nào',
              message:
              'Bấm vào biểu tượng trái tim ở trang chi tiết sản phẩm để lưu các linh kiện bạn muốn theo dõi giá.',
              actionLabel: 'Tìm kiếm linh kiện',
              onAction: () => context.push('/search'),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.63,
            ),
            itemBuilder: (context, index) {
              final product = products[index];
              return ProductCard(
                product: product,
                onTap: () => context.push('/products/${product.id}'),
              );
            },
          );
        },
      ),
    );
  }
}