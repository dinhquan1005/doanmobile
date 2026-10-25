import 'package:equatable/equatable.dart';

enum ProductSortOption {
  newest('Mới nhất'),
  priceAsc('Giá tăng dần'),
  priceDesc('Giá giảm dần'),
  popular('Phổ biến nhất');

  const ProductSortOption(this.label);
  final String label;
}

class ProductFilter extends Equatable {
  const ProductFilter({
    this.searchQuery = '',
    this.parentCategoryId,
    this.categoryId,
    this.brandId,
    this.minPrice,
    this.maxPrice,
    this.onlyInStock = false,
    this.onlyOnSale = false,
    this.specTag,
    this.sortOption = ProductSortOption.newest,
  });

  final String searchQuery;
  final String? parentCategoryId;
  final String? categoryId;
  final String? brandId;
  final int? minPrice;
  final int? maxPrice;
  final bool onlyInStock;
  final bool onlyOnSale;
  final String? specTag;
  final ProductSortOption sortOption;

  bool get hasActiveFilters =>
      (parentCategoryId != null && parentCategoryId!.isNotEmpty) ||
          (categoryId != null && categoryId!.isNotEmpty) ||
          (brandId != null && brandId!.isNotEmpty) ||
          minPrice != null ||
          maxPrice != null ||
          onlyInStock ||
          onlyOnSale ||
          (specTag != null && specTag!.isNotEmpty);

  int get activeFilterCount {
    var count = 0;
    if (categoryId != null || parentCategoryId != null) count++;
    if (brandId != null) count++;
    if (minPrice != null || maxPrice != null) count++;
    if (onlyInStock) count++;
    if (onlyOnSale) count++;
    if (specTag != null && specTag!.isNotEmpty) count++;
    return count;
  }

  ProductFilter copyWith({
    String? searchQuery,
    String? parentCategoryId,
    bool clearParentCategory = false,
    String? categoryId,
    bool clearCategory = false,
    String? brandId,
    bool clearBrand = false,
    int? minPrice,
    bool clearMinPrice = false,
    int? maxPrice,
    bool clearMaxPrice = false,
    bool? onlyInStock,
    bool? onlyOnSale,
    String? specTag,
    bool clearSpecTag = false,
    ProductSortOption? sortOption,
  }) {
    return ProductFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      parentCategoryId: clearParentCategory
          ? null
          : (parentCategoryId ?? this.parentCategoryId),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      brandId: clearBrand ? null : (brandId ?? this.brandId),
      minPrice: clearMinPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      onlyInStock: onlyInStock ?? this.onlyInStock,
      onlyOnSale: onlyOnSale ?? this.onlyOnSale,
      specTag: clearSpecTag ? null : (specTag ?? this.specTag),
      sortOption: sortOption ?? this.sortOption,
    );
  }

  ProductFilter resetFiltersKeepQuery() {
    return ProductFilter(
      searchQuery: searchQuery,
      sortOption: ProductSortOption.newest,
    );
  }

  @override
  List<Object?> get props => [
    searchQuery,
    parentCategoryId,
    categoryId,
    brandId,
    minPrice,
    maxPrice,
    onlyInStock,
    onlyOnSale,
    specTag,
    sortOption,
  ];
}