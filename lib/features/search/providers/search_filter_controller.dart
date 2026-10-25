import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/product_filter.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../home/providers/catalog_providers.dart';

class SearchCatalogState {
  const SearchCatalogState({
    required this.filter,
    this.products = const <ProductModel>[],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.errorMessage,
    this.lastDocument,
  });

  final ProductFilter filter;
  final List<ProductModel> products;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? errorMessage;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;

  SearchCatalogState copyWith({
    ProductFilter? filter,
    List<ProductModel>? products,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? errorMessage,
    bool clearError = false,
    DocumentSnapshot<Map<String, dynamic>>? lastDocument,
    bool clearCursor = false,
  }) {
    return SearchCatalogState(
      filter: filter ?? this.filter,
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastDocument: clearCursor ? null : (lastDocument ?? this.lastDocument),
    );
  }
}

class SearchFilterController extends StateNotifier<SearchCatalogState> {
  SearchFilterController(this._repository)
      : super(const SearchCatalogState(filter: ProductFilter())) {
    fetchFirstPage();
  }

  final CatalogRepository _repository;

  Future<void> fetchFirstPage() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearCursor: true,
    );
    try {
      final result = await _repository.queryProducts(filter: state.filter);
      state = state.copyWith(
        products: result.products,
        lastDocument: result.lastDocument,
        hasMore: result.hasMore,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Không thể tải danh sách linh kiện: $e',
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading ||
        state.isLoadingMore ||
        !state.hasMore ||
        state.lastDocument == null) {
      return;
    }

    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final result = await _repository.queryProducts(
        filter: state.filter,
        startAfterDoc: state.lastDocument,
      );
      final existingIds = state.products.map((p) => p.id).toSet();
      final newItems = result.products
          .where((p) => !existingIds.contains(p.id))
          .toList(growable: false);

      state = state.copyWith(
        products: <ProductModel>[...state.products, ...newItems],
        lastDocument: result.lastDocument,
        hasMore: result.hasMore && newItems.isNotEmpty,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: 'Lỗi khi tải thêm sản phẩm: $e',
      );
    }
  }

  Future<void> updateSearchQuery(String query) async {
    state = state.copyWith(
      filter: state.filter.copyWith(searchQuery: query),
    );
    await fetchFirstPage();
  }

  Future<void> updateSortOption(ProductSortOption sortOption) async {
    state = state.copyWith(
      filter: state.filter.copyWith(sortOption: sortOption),
    );
    await fetchFirstPage();
  }

  Future<void> applyFilter(ProductFilter newFilter) async {
    state = state.copyWith(filter: newFilter);
    await fetchFirstPage();
  }

  Future<void> applyRootCategory(String parentCategoryId) async {
    state = state.copyWith(
      filter: ProductFilter(parentCategoryId: parentCategoryId),
    );
    await fetchFirstPage();
  }

  Future<void> applySubCategory({
    required String? parentCategoryId,
    required String categoryId,
  }) async {
    state = state.copyWith(
      filter: ProductFilter(
        parentCategoryId: parentCategoryId,
        categoryId: categoryId,
      ),
    );
    await fetchFirstPage();
  }

  Future<void> applySaleFilterOnly() async {
    state = state.copyWith(
      filter: const ProductFilter(onlyOnSale: true),
    );
    await fetchFirstPage();
  }

  Future<void> applyPopularSort() async {
    state = state.copyWith(
      filter: const ProductFilter(sortOption: ProductSortOption.popular),
    );
    await fetchFirstPage();
  }

  Future<void> resetAll() async {
    state = state.copyWith(filter: const ProductFilter());
    await fetchFirstPage();
  }
}

final searchFilterControllerProvider =
StateNotifierProvider<SearchFilterController, SearchCatalogState>((ref) {
  return SearchFilterController(ref.watch(catalogRepositoryProvider));
});