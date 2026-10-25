import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/product_card.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/storage_network_image.dart';
import '../../../data/models/banner_model.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/coupon_model.dart';
import '../../../data/models/product_model.dart';
import '../../search/providers/search_filter_controller.dart';
import '../providers/catalog_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isSeeding = false;

  Future<void> _handleSeedDemoCatalog() async {
    setState(() => _isSeeding = true);
    try {
      await ref
          .read(catalogSeedServiceProvider)
          .seedInitialCatalogToFirestore();
      ref.invalidate(homeCatalogBundleProvider);
      ref.invalidate(categoriesListProvider);
      ref.invalidate(brandsListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Đã khởi tạo dữ liệu mẫu linh kiện điện tử lên Cloud Firestore thành công!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể ghi dữ liệu mẫu lên Firestore: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSeeding = false);
      }
    }
  }

  void _openCatalogWithCategory(CategoryModel category) {
    final notifier = ref.read(searchFilterControllerProvider.notifier);
    if (category.isRootCategory) {
      notifier.applyRootCategory(category.id);
    } else {
      notifier.applySubCategory(
        parentCategoryId: category.parentId,
        categoryId: category.id,
      );
    }
    context.push('/search');
  }

  @override
  Widget build(BuildContext context) {
    final homeAsync = ref.watch(homeCatalogBundleProvider);
    final recentAsync = ref.watch(recentlyViewedProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            tooltip: 'Tìm kiếm linh kiện',
            onPressed: () => context.push('/search'),
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(homeCatalogBundleProvider);
          ref.invalidate(recentlyViewedProductsProvider);
          await ref.read(homeCatalogBundleProvider.future);
        },
        child: homeAsync.when(
          loading: () => ListView(
            children: const [
              Padding(
                padding: EdgeInsets.all(16),
                child: SkeletonBox(height: 170, borderRadius: 16),
              ),
              ProductGridSkeleton(itemCount: 4),
            ],
          ),
          error: (error, _) => EmptyOrErrorState(
            icon: Icons.wifi_off_rounded,
            title: 'Không thể tải dữ liệu từ Cloud Firestore',
            message:
            'Vui lòng kiểm tra kết nối mạng hoặc Firestore Security Rules.\nChi tiết: $error',
            actionLabel: 'Thử lại',
            onAction: () => ref.invalidate(homeCatalogBundleProvider),
          ),
          data: (bundle) {
            if (bundle.isCatalogEmpty) {
              return EmptyOrErrorState(
                icon: Icons.inventory_2_outlined,
                title: 'Hệ thống hiện chưa có sản phẩm',
                message:
                'Cơ sở dữ liệu đang trống. Bạn có thể bấm nút bên dưới để khởi tạo danh mục linh kiện ban đầu lên hệ thống.',
                actionLabel: 'Tải lại',
                onAction: () => ref.invalidate(homeCatalogBundleProvider),
                secondaryActionLabel: _isSeeding
                    ? 'Đang nạp dữ liệu...'
                    : 'Khởi tạo danh mục sản phẩm',
                onSecondaryAction: _isSeeding ? null : _handleSeedDemoCatalog,
              );
            }

            final subCategories = bundle.categories
                .where((c) => !c.isRootCategory)
                .toList(growable: false);

            return CustomScrollView(
              slivers: [
                // 1. Thanh tìm kiếm nhanh
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: InkWell(
                      key: const Key('home_quick_search_bar'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => context.push('/search'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outlineVariant,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Tìm CPU, RTX 4060, RAM DDR5, Arduino, mã SKU...',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // 2. Banner quảng cáo
                if (bundle.banners.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _HomeBannerCarousel(banners: bundle.banners),
                  ),

                // 3. Danh mục linh kiện nhanh
                if (subCategories.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _HomeCategoryStrip(
                      categories: subCategories,
                      onSelectCategory: _openCatalogWithCategory,
                    ),
                  ),

                // 5. Sản phẩm nổi bật
                if (bundle.featuredProducts.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _HorizontalProductSection(
                      title: 'Sản phẩm nổi bật',
                      subtitle: 'Linh kiện cấu hình cao được săn đón nhất',
                      products: bundle.featuredProducts,
                      onSeeAll: () {
                        ref
                            .read(searchFilterControllerProvider.notifier)
                            .resetAll();
                        context.push('/search');
                      },
                    ),
                  ),

                // 4. Chương trình khuyến mãi đang có hiệu lực
                if (bundle.activeCoupons.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _ActivePromotionsSection(
                      coupons: bundle.activeCoupons,
                    ),
                  ),

                // 6. Sản phẩm khuyến mãi
                if (bundle.saleProducts.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _HorizontalProductSection(
                      title: 'Đang khuyến mãi giá sốc',
                      subtitle: 'Tiết kiệm chi phí nâng cấp PC & góc làm việc',
                      products: bundle.saleProducts,
                      onSeeAll: () {
                        ref
                            .read(searchFilterControllerProvider.notifier)
                            .applySaleFilterOnly();
                        context.push('/search');
                      },
                    ),
                  ),

                // 7. Sản phẩm mới
                if (bundle.newProducts.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _HorizontalProductSection(
                      title: 'Sản phẩm mới lên kệ',
                      subtitle: 'Thế hệ phần cứng & bo mạch mới nhất',
                      products: bundle.newProducts,
                      onSeeAll: () {
                        ref
                            .read(searchFilterControllerProvider.notifier)
                            .resetAll();
                        context.push('/search');
                      },
                    ),
                  ),

                // 8. Sản phẩm bán chạy
                if (bundle.bestSellingProducts.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _HorizontalProductSection(
                      title: 'Top linh kiện bán chạy',
                      subtitle: 'Được cộng đồng kỹ thuật và game thủ tin dùng',
                      products: bundle.bestSellingProducts,
                      onSeeAll: () {
                        ref
                            .read(searchFilterControllerProvider.notifier)
                            .applyPopularSort();
                        context.push('/search');
                      },
                    ),
                  ),

                // 9. Sản phẩm đã xem gần đây
                SliverToBoxAdapter(
                  child: recentAsync.maybeWhen(
                    data: (recentProducts) {
                      if (recentProducts.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return _HorizontalProductSection(
                        title: 'Sản phẩm đã xem gần đây',
                        subtitle: 'Tiếp tục xem các linh kiện bạn quan tâm',
                        products: recentProducts,
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HomeBannerCarousel extends StatefulWidget {
  const _HomeBannerCarousel({required this.banners});

  final List<BannerModel> banners;

  @override
  State<_HomeBannerCarousel> createState() => _HomeBannerCarouselState();
}

class _HomeBannerCarouselState extends State<_HomeBannerCarousel> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          SizedBox(
            height: 168,
            child: PageView.builder(
              itemCount: widget.banners.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                final banner = widget.banners[index];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      StorageNetworkImage(
                        imageUrlOrPath: banner.imageUrl,
                        fit: BoxFit.cover,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.78),
                              Colors.black.withValues(alpha: 0.15),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              banner.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              banner.subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (widget.banners.length > 1) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.banners.length, (idx) {
                final isSelected = idx == _currentIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 6,
                  width: isSelected ? 20 : 6,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeCategoryStrip extends StatelessWidget {
  const _HomeCategoryStrip({
    required this.categories,
    required this.onSelectCategory,
  });

  final List<CategoryModel> categories;
  final ValueChanged<CategoryModel> onSelectCategory;

  IconData _mapCategoryIcon(String iconKey) {
    return switch (iconKey) {
      'memory' => Icons.memory_rounded,
      'videogame_asset' => Icons.videogame_asset_rounded,
      'storage' => Icons.dns_rounded,
      'sd_storage' => Icons.sd_storage_rounded,
      'settings_input_component' => Icons.settings_input_component_rounded,
      'monitor' => Icons.monitor_rounded,
      'keyboard' => Icons.keyboard_alt_outlined,
      'developer_board' => Icons.developer_board_rounded,
      'sensors' => Icons.sensors_rounded,
      'cable' => Icons.cable_rounded,
      _ => Icons.category_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            'Danh mục linh kiện',
            style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 98,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final cat = categories[index];
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onSelectCategory(cat),
                child: Container(
                  width: 96,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _mapCategoryIcon(cat.iconUrl),
                        color: scheme.primary,
                        size: 28,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        cat.name,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ActivePromotionsSection extends StatelessWidget {
  const _ActivePromotionsSection({required this.coupons});

  final List<CouponModel> coupons;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chương trình khuyến mãi & Mã giảm giá',
            style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: coupons.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final coupon = coupons[index];
                return Container(
                  width: 280,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          coupon.code,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              coupon.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              coupon.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HorizontalProductSection extends StatelessWidget {
  const _HorizontalProductSection({
    required this.title,
    required this.subtitle,
    required this.products,
    this.onSeeAll,
  });

  final String title;
  final String subtitle;
  final List<ProductModel> products;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onSeeAll != null)
                  TextButton(
                    onPressed: onSeeAll,
                    child: const Text('Xem tất cả'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 292,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final product = products[index];
                return SizedBox(
                  width: 182,
                  child: ProductCard(
                    product: product,
                    onTap: () => context.push('/products/${product.id}'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
