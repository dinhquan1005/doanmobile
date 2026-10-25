import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/product_card.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/brand_model.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/product_filter.dart';
import '../../home/providers/catalog_providers.dart';
import '../providers/search_filter_controller.dart';

class CatalogSearchScreen extends ConsumerStatefulWidget {
  const CatalogSearchScreen({super.key});

  @override
  ConsumerState<CatalogSearchScreen> createState() =>
      _CatalogSearchScreenState();
}

class _CatalogSearchScreenState extends ConsumerState<CatalogSearchScreen> {
  late final TextEditingController _searchController;
  final ScrollController _scrollController = ScrollController();

  static const List<String> _commonSpecTags = <String>[
    'Socket:LGA1700',
    'Socket:AM5',
    'RAM:DDR5',
    'RAM:DDR4',
    'VRAM:8GB',
    'SSD:NVMeGen4',
    'DIY:Arduino',
    'DIY:WiFi',
  ];

  @override
  void initState() {
    super.initState();
    final currentQuery =
        ref.read(searchFilterControllerProvider).filter.searchQuery;
    _searchController = TextEditingController(text: currentQuery);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 240) {
      ref.read(searchFilterControllerProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openFilterBottomSheet(
      List<CategoryModel> categories,
      List<BrandModel> brands,
      ) async {
    final currentFilter = ref.read(searchFilterControllerProvider).filter;
    final updatedFilter = await showModalBottomSheet<ProductFilter>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ProductFilterBottomSheet(
        initialFilter: currentFilter,
        categories: categories,
        brands: brands,
        availableSpecTags: _commonSpecTags,
      ),
    );

    if (updatedFilter != null) {
      await ref
          .read(searchFilterControllerProvider.notifier)
          .applyFilter(updatedFilter);
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchFilterControllerProvider);
    final categories =
        ref.watch(categoriesListProvider).valueOrNull ?? const <CategoryModel>[];
    final brands =
        ref.watch(brandsListProvider).valueOrNull ?? const <BrandModel>[];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: TextField(
            key: const Key('catalog_search_input'),
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (value) {
              ref
                  .read(searchFilterControllerProvider.notifier)
                  .updateSearchQuery(value);
            },
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Tìm theo tên, mã SKU, thương hiệu, model...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18),
                onPressed: () {
                  _searchController.clear();
                  ref
                      .read(searchFilterControllerProvider.notifier)
                      .updateSearchQuery('');
                  setState(() {});
                },
              )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        actions: [
          Badge(
            isLabelVisible: searchState.filter.activeFilterCount > 0,
            label: Text('${searchState.filter.activeFilterCount}'),
            child: IconButton(
              key: const Key('open_filter_sheet_button'),
              tooltip: 'Bộ lọc kỹ thuật & Giá',
              onPressed: () => _openFilterBottomSheet(categories, brands),
              icon: const Icon(Icons.tune_rounded),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Thanh sắp xếp & Hiển thị chip bộ lọc đang áp dụng
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  'Sắp xếp:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(width: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<ProductSortOption>(
                    key: const Key('sort_dropdown_button'),
                    value: searchState.filter.sortOption,
                    isDense: true,
                    items: ProductSortOption.values.map((option) {
                      return DropdownMenuItem<ProductSortOption>(
                        value: option,
                        child: Text(
                          option.label,
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: (option) {
                      if (option != null) {
                        ref
                            .read(searchFilterControllerProvider.notifier)
                            .updateSortOption(option);
                      }
                    },
                  ),
                ),
                const Spacer(),
                if (searchState.filter.hasActiveFilters)
                  TextButton.icon(
                    onPressed: () {
                      ref
                          .read(searchFilterControllerProvider.notifier)
                          .applyFilter(
                        searchState.filter.resetFiltersKeepQuery(),
                      );
                    },
                    icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                    label: const Text('Xóa lọc'),
                  ),
              ],
            ),
          ),

          // Lưới sản phẩm
          Expanded(
            child: Builder(
              builder: (context) {
                if (searchState.isLoading) {
                  return const SingleChildScrollView(
                    child: ProductGridSkeleton(itemCount: 6),
                  );
                }

                if (searchState.errorMessage != null &&
                    searchState.products.isEmpty) {
                  return EmptyOrErrorState(
                    icon: Icons.error_outline_rounded,
                    title: 'Không thể tải danh sách sản phẩm',
                    message: searchState.errorMessage!,
                    actionLabel: 'Thử lại',
                    onAction: () => ref
                        .read(searchFilterControllerProvider.notifier)
                        .fetchFirstPage(),
                  );
                }

                if (searchState.products.isEmpty) {
                  return EmptyOrErrorState(
                    icon: Icons.search_off_rounded,
                    title: 'Không tìm thấy linh kiện phù hợp',
                    message:
                    'Hãy thử thay đổi từ khóa tìm kiếm, mã SKU hoặc nới rộng khoảng giá trong bộ lọc.',
                    actionLabel: 'Đặt lại toàn bộ bộ lọc',
                    onAction: () {
                      _searchController.clear();
                      ref
                          .read(searchFilterControllerProvider.notifier)
                          .resetAll();
                    },
                  );
                }

                return GridView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: searchState.products.length +
                      (searchState.isLoadingMore ? 1 : 0),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.63,
                  ),
                  itemBuilder: (context, index) {
                    if (index >= searchState.products.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    final product = searchState.products[index];
                    return ProductCard(
                      product: product,
                      onTap: () => context.push('/products/${product.id}'),
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

class _ProductFilterBottomSheet extends StatefulWidget {
  const _ProductFilterBottomSheet({
    required this.initialFilter,
    required this.categories,
    required this.brands,
    required this.availableSpecTags,
  });

  final ProductFilter initialFilter;
  final List<CategoryModel> categories;
  final List<BrandModel> brands;
  final List<String> availableSpecTags;

  @override
  State<_ProductFilterBottomSheet> createState() =>
      _ProductFilterBottomSheetState();
}

class _ProductFilterBottomSheetState extends State<_ProductFilterBottomSheet> {
  late ProductFilter _draft;
  late final TextEditingController _minPriceCtrl;
  late final TextEditingController _maxPriceCtrl;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialFilter;
    _minPriceCtrl = TextEditingController(
      text: _draft.minPrice?.toString() ?? '',
    );
    _maxPriceCtrl = TextEditingController(
      text: _draft.maxPrice?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subCategories =
    widget.categories.where((c) => !c.isRootCategory).toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Bộ lọc linh kiện điện tử',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _draft = _draft.resetFiltersKeepQuery();
                      _minPriceCtrl.clear();
                      _maxPriceCtrl.clear();
                    });
                  },
                  child: const Text('Thiết lập lại'),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Khoảng giá (VND)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minPriceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Từ (VND)',
                      hintText: '500000',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maxPriceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Đến (VND)',
                      hintText: '15000000',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('Dưới 1 triệu'),
                  onPressed: () {
                    _minPriceCtrl.text = '0';
                    _maxPriceCtrl.text = '1000000';
                  },
                ),
                ActionChip(
                  label: const Text('1 - 5 triệu'),
                  onPressed: () {
                    _minPriceCtrl.text = '1000000';
                    _maxPriceCtrl.text = '5000000';
                  },
                ),
                ActionChip(
                  label: const Text('Trên 5 triệu'),
                  onPressed: () {
                    _minPriceCtrl.text = '5000000';
                    _maxPriceCtrl.clear();
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (subCategories.isNotEmpty) ...[
              const Text(
                'Danh mục con',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: subCategories.map((cat) {
                  final selected = _draft.categoryId == cat.id;
                  return FilterChip(
                    label: Text(cat.name),
                    selected: selected,
                    onSelected: (val) {
                      setState(() {
                        _draft = _draft.copyWith(
                          categoryId: val ? cat.id : null,
                          clearCategory: !val,
                          clearParentCategory: true,
                        );
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
            ],
            if (widget.brands.isNotEmpty) ...[
              const Text(
                'Thương hiệu',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: widget.brands.map((brand) {
                  final selected = _draft.brandId == brand.id;
                  return FilterChip(
                    label: Text(brand.name),
                    selected: selected,
                    onSelected: (val) {
                      setState(() {
                        _draft = _draft.copyWith(
                          brandId: val ? brand.id : null,
                          clearBrand: !val,
                        );
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
            ],
            const Text(
              'Thông số kỹ thuật nhanh',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: widget.availableSpecTags.map((tag) {
                final selected = _draft.specTag == tag;
                return FilterChip(
                  label: Text(tag),
                  selected: selected,
                  onSelected: (val) {
                    setState(() {
                      _draft = _draft.copyWith(
                        specTag: val ? tag : null,
                        clearSpecTag: !val,
                      );
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Chỉ hiển thị sản phẩm còn hàng'),
              value: _draft.onlyInStock,
              onChanged: (val) {
                setState(() => _draft = _draft.copyWith(onlyInStock: val));
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Chỉ hiển thị sản phẩm đang giảm giá'),
              value: _draft.onlyOnSale,
              onChanged: (val) {
                setState(() => _draft = _draft.copyWith(onlyOnSale: val));
              },
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                final minP = CurrencyFormatter.tryParseVnd(_minPriceCtrl.text);
                final maxP = CurrencyFormatter.tryParseVnd(_maxPriceCtrl.text);
                final result = _draft.copyWith(
                  minPrice: minP,
                  clearMinPrice: minP == null,
                  maxPrice: maxP,
                  clearMaxPrice: maxP == null,
                );
                Navigator.of(context).pop(result);
              },
              child: const Text('Áp dụng bộ lọc'),
            ),
          ],
        ),
      ),
    );
  }
}