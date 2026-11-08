import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/brand_model.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/product_model.dart';
import '../../home/providers/catalog_providers.dart';
import 'admin_dashboard_screen.dart';

/// Màn hình Thêm mới / Chỉnh sửa Linh kiện dành cho Quản trị viên
class AdminProductFormScreen extends ConsumerStatefulWidget {
  const AdminProductFormScreen({
    super.key,
    this.initialProduct,
  });

  final ProductModel? initialProduct;

  bool get isEditing => initialProduct != null;

  @override
  ConsumerState<AdminProductFormScreen> createState() =>
      _AdminProductFormScreenState();
}

class _AdminProductFormScreenState extends ConsumerState<AdminProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _skuController;
  late final TextEditingController _modelController;
  late final TextEditingController _priceController;
  late final TextEditingController _salePriceController;
  late final TextEditingController _stockController;
  late final TextEditingController _thumbnailController;
  late final TextEditingController _shortDescController;
  late final TextEditingController _descController;
  late final TextEditingController _warrantyController;

  String? _selectedCategoryId;
  String? _selectedBrandId;
  bool _isFeatured = false;
  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initialProduct;
    _nameController = TextEditingController(text: p?.name ?? '');
    _skuController = TextEditingController(text: p?.sku ?? '');
    _modelController = TextEditingController(text: p?.model ?? '');
    _priceController =
        TextEditingController(text: p != null ? '${p.price}' : '');
    _salePriceController =
        TextEditingController(text: p?.salePrice != null ? '${p!.salePrice}' : '');
    _stockController =
        TextEditingController(text: p != null ? '${p.stockQuantity}' : '10');
    _thumbnailController = TextEditingController(
      text: p?.thumbnailUrl ??
          'https://images.unsplash.com/photo-1591799264318-7e6ef8ddb7ea?w=600',
    );
    _shortDescController =
        TextEditingController(text: p?.shortDescription ?? '');
    _descController = TextEditingController(text: p?.description ?? '');
    _warrantyController =
        TextEditingController(text: p != null ? '${p.warrantyMonths}' : '36');

    _selectedCategoryId = p?.categoryId;
    _selectedBrandId = p?.brandId;
    _isFeatured = p?.isFeatured ?? false;
    _isActive = p?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _modelController.dispose();
    _priceController.dispose();
    _salePriceController.dispose();
    _stockController.dispose();
    _thumbnailController.dispose();
    _shortDescController.dispose();
    _descController.dispose();
    _warrantyController.dispose();
    super.dispose();
  }

  void _useSampleImage(String url) {
    setState(() {
      _thumbnailController.text = url;
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(catalogRepositoryProvider);
      final categories =
          ref.read(categoriesListProvider).valueOrNull ?? const <CategoryModel>[];
      final brands =
          ref.read(brandsListProvider).valueOrNull ?? const <BrandModel>[];

      final now = DateTime.now().toUtc();
      final category = categories.firstWhere(
        (c) => c.id == _selectedCategoryId,
        orElse: () => categories.isNotEmpty
            ? categories.first
            : CategoryModel(
                id: 'pc-core',
                name: 'Linh kiện PC Core',
                slug: 'pc-core',
                iconUrl: 'memory',
                sortOrder: 1,
                createdAt: now,
                updatedAt: now,
              ),
      );

      final brand = brands.firstWhere(
        (b) => b.id == _selectedBrandId,
        orElse: () => brands.isNotEmpty
            ? brands.first
            : BrandModel(
                id: 'intel',
                name: 'Intel',
                slug: 'intel',
                logoUrl: 'intel',
                sortOrder: 1,
                createdAt: now,
              ),
      );

      final price = int.parse(_priceController.text.replaceAll(RegExp(r'\D'), ''));
      final salePriceRaw = _salePriceController.text.trim();
      final salePrice = salePriceRaw.isNotEmpty
          ? int.tryParse(salePriceRaw.replaceAll(RegExp(r'\D'), ''))
          : null;
      final stockQuantity =
          int.tryParse(_stockController.text.trim()) ?? 0;
      final warrantyMonths =
          int.tryParse(_warrantyController.text.trim()) ?? 12;

      final productId = widget.initialProduct?.id ??
          'prod-${_skuController.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}-${const Uuid().v4().substring(0, 4)}';

      final name = _nameController.text.trim();
      final sku = _skuController.text.trim().toUpperCase();
      final model = _modelController.text.trim().isNotEmpty
          ? _modelController.text.trim()
          : sku;

      final searchKeywords = ProductModel.generateSearchKeywords(
        name: name,
        sku: sku,
        brandName: brand.name,
        model: model,
      );

      final product = ProductModel(
        id: productId,
        sku: sku,
        name: name,
        nameLower: name.toLowerCase(),
        searchKeywords: searchKeywords,
        categoryId: category.id,
        parentCategoryId: category.parentId ?? category.id,
        brandId: brand.id,
        brandName: brand.name,
        model: model,
        price: price,
        salePrice: salePrice,
        effectivePrice: salePrice ?? price,
        stockQuantity: stockQuantity,
        reservedQuantity: widget.initialProduct?.reservedQuantity ?? 0,
        availableStock: stockQuantity,
        inStock: stockQuantity > 0,
        thumbnailUrl: _thumbnailController.text.trim(),
        imageUrls: [_thumbnailController.text.trim()],
        shortDescription: _shortDescController.text.trim().isNotEmpty
            ? _shortDescController.text.trim()
            : name,
        description: _descController.text.trim().isNotEmpty
            ? _descController.text.trim()
            : name,
        specifications: widget.initialProduct?.specifications ??
            const <String, String>{
              'Thương hiệu': 'Chính hãng',
              'Bảo hành': 'Tiêu chuẩn nhà sản xuất',
            },
        warrantyMonths: warrantyMonths,
        warrantyPolicy: 'Bảo hành chính hãng $warrantyMonths tháng.',
        ratingAvg: widget.initialProduct?.ratingAvg ?? 5.0,
        ratingCount: widget.initialProduct?.ratingCount ?? 1,
        soldCount: widget.initialProduct?.soldCount ?? 0,
        isFeatured: _isFeatured,
        isNew: !widget.isEditing,
        isOnSale: salePrice != null && salePrice < price,
        isActive: _isActive,
        isDeleted: false,
        createdAt: widget.initialProduct?.createdAt ?? now,
        updatedAt: now,
      );

      if (widget.isEditing) {
        await repo.updateProduct(product);
      } else {
        await repo.createProduct(product);
      }

      // Làm mới dữ liệu
      ref.invalidate(adminDashboardStatsProvider);
      ref.invalidate(homeCatalogBundleProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              widget.isEditing
                  ? 'Đã cập nhật linh kiện: ${product.name}'
                  : 'Đã thêm mới thành công: ${product.name}',
            ),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.error,
            content: Text('Lỗi khi lưu sản phẩm: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(categoriesListProvider);
    final brandsAsync = ref.watch(brandsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Chỉnh sửa linh kiện' : 'Thêm mới linh kiện PC / DIY',
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: FilledButton.icon(
            key: const Key('admin_save_product_button'),
            onPressed: _isSaving ? null : _handleSave,
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(
              _isSaving
                  ? 'Đang lưu vào Firestore...'
                  : (widget.isEditing ? 'Lưu thay đổi' : 'Thêm linh kiện vào kho'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Thông tin cơ bản
            Text(
              '1. Thông tin chung & Nhận diện',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('admin_product_name_input'),
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Tên linh kiện *',
                hintText: 'Ví dụ: Vi xử lý Intel Core i5-13400F',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.drive_file_rename_outline_rounded),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Vui lòng nhập tên sản phẩm'
                  : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('admin_product_sku_input'),
                    controller: _skuController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Mã SKU *',
                      hintText: 'CPU-INTEL-I5-13400F',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.qr_code_rounded),
                    ),
                    validator: AppValidators.validateSku,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _modelController,
                    decoration: const InputDecoration(
                      labelText: 'Mã Model',
                      hintText: 'Core i5-13400F',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.tag_rounded),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Danh mục & Thương hiệu
            Text(
              '2. Phân loại & Thương hiệu',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            categoriesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox(),
              data: (categories) {
                // Chỉ lấy các danh mục con hoặc danh mục độc lập
                final now = DateTime.now().toUtc();
                final selectableCategories = categories.isNotEmpty
                    ? categories
                    : [
                        CategoryModel(
                          id: 'cpu',
                          name: 'Vi xử lý (CPU)',
                          slug: 'cpu',
                          iconUrl: 'memory',
                          sortOrder: 1,
                          createdAt: now,
                          updatedAt: now,
                        ),
                      ];

                if (_selectedCategoryId == null && selectableCategories.isNotEmpty) {
                  _selectedCategoryId = selectableCategories.first.id;
                }

                return DropdownButtonFormField<String>(
                  key: const Key('admin_product_category_select'),
                  initialValue: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Danh mục linh kiện *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category_rounded),
                  ),
                  items: selectableCategories.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat.id,
                      child: Text(cat.name),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedCategoryId = val),
                  validator: (v) => v == null ? 'Vui lòng chọn danh mục' : null,
                );
              },
            ),
            const SizedBox(height: 12),
            brandsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox(),
              data: (brands) {
                final now = DateTime.now().toUtc();
                final selectableBrands = brands.isNotEmpty
                    ? brands
                    : [
                        BrandModel(
                          id: 'intel',
                          name: 'Intel',
                          slug: 'intel',
                          logoUrl: 'intel',
                          sortOrder: 1,
                          createdAt: now,
                        ),
                      ];

                if (_selectedBrandId == null && selectableBrands.isNotEmpty) {
                  _selectedBrandId = selectableBrands.first.id;
                }

                return DropdownButtonFormField<String>(
                  key: const Key('admin_product_brand_select'),
                  initialValue: _selectedBrandId,
                  decoration: const InputDecoration(
                    labelText: 'Thương hiệu sản xuất *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.business_rounded),
                  ),
                  items: selectableBrands.map((b) {
                    return DropdownMenuItem<String>(
                      value: b.id,
                      child: Text(b.name),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedBrandId = val),
                  validator: (v) => v == null ? 'Vui lòng chọn thương hiệu' : null,
                );
              },
            ),
            const SizedBox(height: 16),

            // Giá & Tồn kho
            Text(
              '3. Giá bán VND & Số lượng kho',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('admin_product_price_input'),
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Giá niêm yết (₫) *',
                      hintText: '4690000',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money_rounded),
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return (n == null || n <= 0)
                          ? 'Giá phải lớn hơn 0 ₫'
                          : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: const Key('admin_product_sale_price_input'),
                    controller: _salePriceController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Giá khuyến mãi (₫)',
                      hintText: 'Tùy chọn',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.local_offer_rounded),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('admin_product_stock_input'),
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Số lượng tồn kho *',
                      hintText: '35',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.warehouse_rounded),
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return (n == null || n < 0) ? 'Tồn kho không hợp lệ' : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _warrantyController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Bảo hành (tháng)',
                      hintText: '36',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.verified_user_rounded),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Ảnh đại diện
            Text(
              '4. Hình ảnh & Trưng bày',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('admin_product_image_input'),
              controller: _thumbnailController,
              decoration: const InputDecoration(
                labelText: 'URL hình ảnh sản phẩm *',
                hintText: 'https://images.unsplash.com/...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.image_rounded),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Vui lòng cung cấp link hình ảnh'
                  : null,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ActionChip(
                  label: const Text('Ảnh CPU mẫu'),
                  onPressed: () => _useSampleImage(
                    'https://images.unsplash.com/photo-1591799264318-7e6ef8ddb7ea?w=600',
                  ),
                ),
                ActionChip(
                  label: const Text('Ảnh GPU mẫu'),
                  onPressed: () => _useSampleImage(
                    'https://images.unsplash.com/photo-1587202372775-e229f172b9d7?w=600',
                  ),
                ),
                ActionChip(
                  label: const Text('Ảnh Arduino DIY mẫu'),
                  onPressed: () => _useSampleImage(
                    'https://images.unsplash.com/photo-1553406830-ef2513450d76?w=600',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Mô tả
            Text(
              '5. Mô tả chi tiết',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _shortDescController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Mô tả ngắn (hiển thị tóm tắt)',
                hintText: 'Vi xử lý thế hệ 13 socket LGA1700...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Mô tả chi tiết',
                hintText: 'Đặc điểm kỹ thuật, hiệu năng chơi game và làm việc...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Tùy chọn hiển thị
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Đánh dấu là Sản phẩm nổi bật (Featured)'),
                    subtitle: const Text('Hiển thị trên mục Nổi bật ở Trang chủ'),
                    value: _isFeatured,
                    onChanged: (val) => setState(() => _isFeatured = val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Trạng thái kinh doanh (Active)'),
                    subtitle: const Text('Bật để hiển thị cho khách hàng xem và mua'),
                    value: _isActive,
                    onChanged: (val) => setState(() => _isActive = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
