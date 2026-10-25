import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/state_views.dart';
import '../../home/providers/catalog_providers.dart';
import '../../search/providers/search_filter_controller.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  String? _selectedParentId;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesListProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh mục linh kiện'),
        actions: [
          IconButton(
            tooltip: 'Tìm kiếm & Bộ lọc',
            onPressed: () => context.push('/search'),
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => EmptyOrErrorState(
          icon: Icons.error_outline_rounded,
          title: 'Không thể tải danh mục sản phẩm',
          message: '$err',
          actionLabel: 'Thử lại',
          onAction: () => ref.invalidate(categoriesListProvider),
        ),
        data: (allCategories) {
          final rootCategories = allCategories
              .where((c) => c.isRootCategory)
              .toList(growable: false);

          if (rootCategories.isEmpty) {
            return EmptyOrErrorState(
              icon: Icons.category_outlined,
              title: 'Chưa có danh mục nào trên Firestore',
              message:
              'Hãy mở tab Trang chủ để khởi tạo dữ liệu mẫu hoặc thêm danh mục từ Admin.',
              actionLabel: 'Tải lại',
              onAction: () => ref.invalidate(categoriesListProvider),
            );
          }

          final activeParentId =
              _selectedParentId ?? rootCategories.first.id;
          final activeParent = rootCategories.firstWhere(
                (c) => c.id == activeParentId,
            orElse: () => rootCategories.first,
          );

          final childCategories = allCategories
              .where((c) => c.parentId == activeParent.id)
              .toList(growable: false);

          return Row(
            children: [
              // Cột trái: Danh mục cha
              Container(
                width: 132,
                color: scheme.surface,
                child: ListView.builder(
                  itemCount: rootCategories.length,
                  itemBuilder: (context, index) {
                    final rootCat = rootCategories[index];
                    final isSelected = rootCat.id == activeParent.id;
                    return InkWell(
                      onTap: () {
                        setState(() => _selectedParentId = rootCat.id);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? scheme.primaryContainer.withValues(alpha: 0.5)
                              : Colors.transparent,
                          border: Border(
                            left: BorderSide(
                              color: isSelected
                                  ? scheme.primary
                                  : Colors.transparent,
                              width: 4,
                            ),
                          ),
                        ),
                        child: Text(
                          rootCat.name,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? scheme.primary
                                : scheme.onSurface,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const VerticalDivider(width: 1),
              // Cột phải: Danh mục con và nút xem tất cả
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        child: ListTile(
                          title: Text(
                            activeParent.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text(
                            'Xem toàn bộ sản phẩm thuộc nhóm này',
                          ),
                          trailing: const Icon(Icons.arrow_forward_rounded),
                          onTap: () {
                            ref
                                .read(searchFilterControllerProvider.notifier)
                                .applyRootCategory(activeParent.id);
                            context.push('/search');
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Danh mục chi tiết',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: GridView.builder(
                          itemCount: childCategories.length,
                          gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.25,
                          ),
                          itemBuilder: (context, index) {
                            final subCat = childCategories[index];
                            return Card(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  ref
                                      .read(
                                    searchFilterControllerProvider.notifier,
                                  )
                                      .applySubCategory(
                                    parentCategoryId: activeParent.id,
                                    categoryId: subCat.id,
                                  );
                                  context.push('/search');
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.developer_board_rounded,
                                        color: scheme.primary,
                                        size: 28,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        subCat.name,
                                        maxLines: 2,
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                      if (subCat
                                          .specTemplateKeys.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          subCat.specTemplateKeys
                                              .take(2)
                                              .join(' • '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}