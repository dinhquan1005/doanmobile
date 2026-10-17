import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../data/models/product_model.dart';
import '../utils/currency_formatter.dart';
import 'storage_network_image.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  final ProductModel product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ảnh tỷ lệ đồng nhất 1:1 + Badge giảm giá & tình trạng kho
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    StorageNetworkImage(
                      imageUrlOrPath: product.thumbnailUrl,
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    if (product.hasDiscount)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
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
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    if (!product.inStock)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'TẠM HẾT HÀNG',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Thương hiệu & Tình trạng kho
              Row(
                children: [
                  Expanded(
                    child: Text(
                      product.brandName.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: scheme.secondary,
                      ),
                    ),
                  ),
                  Text(
                    product.inStock
                        ? 'Còn ${product.availableStock}'
                        : 'Hết hàng',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: product.inStock
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Tên sản phẩm cố định chiều cao 2 dòng chống tràn bố cục
              Expanded(
                child: Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Giá khuyến mãi & Giá gốc VND
              Text(
                CurrencyFormatter.formatVnd(product.effectivePrice),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
              ),
              if (product.hasDiscount)
                Text(
                  CurrencyFormatter.formatVnd(product.price),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant,
                    decoration: TextDecoration.lineThrough,
                  ),
                )
              else
                const SizedBox(height: 15),
              const SizedBox(height: 4),
              // Đánh giá sao & Đã bán
              Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 14,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    product.ratingAvg.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Đã bán ${product.soldCount}',
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
