import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firestore_collections.dart';
import '../models/banner_model.dart';
import '../models/brand_model.dart';
import '../models/category_model.dart';
import '../models/coupon_model.dart';
import '../models/product_model.dart';
import '../models/review_model.dart';

class CatalogSeedService {
  CatalogSeedService(this._firestore);

  final FirebaseFirestore _firestore;

  Future<void> seedInitialCatalogToFirestore() async {
    final now = DateTime.now().toUtc();
    final batch = _firestore.batch();

    // 1. Seed Danh mục cha & Danh mục con
    final categories = <CategoryModel>[
      CategoryModel(
        id: 'pc-core',
        name: 'Linh kiện PC Core',
        slug: 'pc-core',
        parentId: null,
        iconUrl: 'memory',
        sortOrder: 1,
        createdAt: now,
        updatedAt: now,
      ),
      CategoryModel(
        id: 'peripherals-monitors',
        name: 'Màn hình & Gaming Gear',
        slug: 'peripherals-monitors',
        parentId: null,
        iconUrl: 'desktop_windows',
        sortOrder: 2,
        createdAt: now,
        updatedAt: now,
      ),
      CategoryModel(
        id: 'diy-iot',
        name: 'Linh kiện Điện tử DIY & IoT',
        slug: 'diy-iot',
        parentId: null,
        iconUrl: 'developer_board',
        sortOrder: 3,
        createdAt: now,
        updatedAt: now,
      ),
      CategoryModel(
        id: 'cables-networking',
        name: 'Cáp, Hub & Thiết bị mạng',
        slug: 'cables-networking',
        parentId: null,
        iconUrl: 'router',
        sortOrder: 4,
        createdAt: now,
        updatedAt: now,
      ),
      // Danh mục con của PC Core
      CategoryModel(
        id: 'cpu',
        name: 'Vi xử lý (CPU)',
        slug: 'cpu',
        parentId: 'pc-core',
        iconUrl: 'memory',
        sortOrder: 1,
        specTemplateKeys: const ['Socket', 'Số nhân / Số luồng', 'Xung nhịp', 'TDP'],
        createdAt: now,
        updatedAt: now,
      ),
      CategoryModel(
        id: 'gpu',
        name: 'Card đồ họa (GPU)',
        slug: 'gpu',
        parentId: 'pc-core',
        iconUrl: 'videogame_asset',
        sortOrder: 2,
        specTemplateKeys: const ['VRAM', 'Chuẩn Bus', 'Nguồn khuyến nghị'],
        createdAt: now,
        updatedAt: now,
      ),
      CategoryModel(
        id: 'ram',
        name: 'Bộ nhớ RAM',
        slug: 'ram',
        parentId: 'pc-core',
        iconUrl: 'storage',
        sortOrder: 3,
        specTemplateKeys: const ['Chuẩn RAM', 'Dung lượng', 'Bus RAM'],
        createdAt: now,
        updatedAt: now,
      ),
      CategoryModel(
        id: 'ssd-hdd',
        name: 'Ổ cứng SSD / HDD',
        slug: 'ssd-hdd',
        parentId: 'pc-core',
        iconUrl: 'sd_storage',
        sortOrder: 4,
        specTemplateKeys: const ['Dung lượng', 'Chuẩn giao tiếp', 'Tốc độ đọc'],
        createdAt: now,
        updatedAt: now,
      ),
      CategoryModel(
        id: 'mainboard-psu',
        name: 'Mainboard, Nguồn & Case',
        slug: 'mainboard-psu',
        parentId: 'pc-core',
        iconUrl: 'settings_input_component',
        sortOrder: 5,
        specTemplateKeys: const ['Socket hỗ trợ', 'Kích thước', 'Khe RAM'],
        createdAt: now,
        updatedAt: now,
      ),
      // Danh mục con của Màn hình & Gear
      CategoryModel(
        id: 'monitors',
        name: 'Màn hình máy tính',
        slug: 'monitors',
        parentId: 'peripherals-monitors',
        iconUrl: 'monitor',
        sortOrder: 1,
        specTemplateKeys: const ['Kích thước', 'Độ phân giải', 'Tần số quét'],
        createdAt: now,
        updatedAt: now,
      ),
      CategoryModel(
        id: 'keyboards-mice',
        name: 'Bàn phím, Chuột & Tai nghe',
        slug: 'keyboards-mice',
        parentId: 'peripherals-monitors',
        iconUrl: 'keyboard',
        sortOrder: 2,
        specTemplateKeys: const ['Kết nối', 'Switch / Cảm biến'],
        createdAt: now,
        updatedAt: now,
      ),
      // Danh mục con của DIY & IoT
      CategoryModel(
        id: 'arduino-mcu',
        name: 'Arduino & Vi điều khiển',
        slug: 'arduino-mcu',
        parentId: 'diy-iot',
        iconUrl: 'developer_board',
        sortOrder: 1,
        specTemplateKeys: const ['Vi điều khiển', 'Điện áp hoạt động', 'Flash'],
        createdAt: now,
        updatedAt: now,
      ),
      CategoryModel(
        id: 'sensors-ic',
        name: 'Cảm biến, IC, Điện trở & Tụ điện',
        slug: 'sensors-ic',
        parentId: 'diy-iot',
        iconUrl: 'sensors',
        sortOrder: 2,
        specTemplateKeys: const ['Điện áp', 'Chuẩn giao tiếp'],
        createdAt: now,
        updatedAt: now,
      ),
      // Danh mục con của Cáp & Mạng
      CategoryModel(
        id: 'networking-cables',
        name: 'Router Wi-Fi, Cáp & Bộ chuyển đổi',
        slug: 'networking-cables',
        parentId: 'cables-networking',
        iconUrl: 'cable',
        sortOrder: 1,
        specTemplateKeys: const ['Chuẩn kết nối', 'Băng thông'],
        createdAt: now,
        updatedAt: now,
      ),
    ];

    for (final category in categories) {
      final ref = _firestore
          .collection(FirestoreCollections.categories)
          .doc(category.id);
      batch.set(ref, category.toFirestoreMap());
    }

    // 2. Seed Thương hiệu
    final brands = <BrandModel>[
      BrandModel(
        id: 'intel',
        name: 'Intel',
        slug: 'intel',
        logoUrl: 'https://images.unsplash.com/photo-1591799264318-7e6ef8ddb7ea?w=300',
        originCountry: 'Hoa Kỳ',
        sortOrder: 1,
        createdAt: now,
      ),
      BrandModel(
        id: 'amd',
        name: 'AMD',
        slug: 'amd',
        logoUrl: 'https://images.unsplash.com/photo-1555617778-02518510b9fa?w=300',
        originCountry: 'Hoa Kỳ',
        sortOrder: 2,
        createdAt: now,
      ),
      BrandModel(
        id: 'asus',
        name: 'ASUS',
        slug: 'asus',
        logoUrl: 'https://images.unsplash.com/photo-1587202372775-e229f172b9d7?w=300',
        originCountry: 'Đài Loan',
        sortOrder: 3,
        createdAt: now,
      ),
      BrandModel(
        id: 'kingston',
        name: 'Kingston',
        slug: 'kingston',
        logoUrl: 'https://images.unsplash.com/photo-1562976540-1502c2145186?w=300',
        originCountry: 'Hoa Kỳ',
        sortOrder: 4,
        createdAt: now,
      ),
      BrandModel(
        id: 'samsung',
        name: 'Samsung',
        slug: 'samsung',
        logoUrl: 'https://images.unsplash.com/photo-1597872200969-2b65d56bd16b?w=300',
        originCountry: 'Hàn Quốc',
        sortOrder: 5,
        createdAt: now,
      ),
      BrandModel(
        id: 'arduino',
        name: 'Arduino',
        slug: 'arduino',
        logoUrl: 'https://images.unsplash.com/photo-1553406830-ef2513450d76?w=300',
        originCountry: 'Ý',
        sortOrder: 6,
        createdAt: now,
      ),
    ];

    for (final brand in brands) {
      final ref =
      _firestore.collection(FirestoreCollections.brands).doc(brand.id);
      batch.set(ref, brand.toFirestoreMap());
    }

    // 3. Seed Banners trang chủ
    final banners = <BannerModel>[
      BannerModel(
        id: 'banner-rtx-build',
        title: 'Nâng cấp PC Gaming & Đồ họa 2026',
        subtitle: 'Giảm đến 18% combo CPU Intel Gen 14, RAM DDR5 & SSD NVMe Gen4',
        imageUrl: 'https://images.unsplash.com/photo-1587202372775-e229f172b9d7?w=1000',
        targetType: 'category',
        targetId: 'pc-core',
        sortOrder: 1,
        createdAt: now,
      ),
      BannerModel(
        id: 'banner-diy-iot',
        title: 'Thế giới Vi điều khiển, Cảm biến & Arduino DIY',
        subtitle: 'Đầy đủ kit thực hành nhúng, ESP32, cảm biến, IC và linh kiện thụ động',
        imageUrl: 'https://images.unsplash.com/photo-1553406830-ef2513450d76?w=1000',
        targetType: 'category',
        targetId: 'diy-iot',
        sortOrder: 2,
        createdAt: now,
      ),
    ];

    for (final banner in banners) {
      final ref =
      _firestore.collection(FirestoreCollections.banners).doc(banner.id);
      batch.set(ref, banner.toFirestoreMap());
    }

    // 4. Seed Mã giảm giá đang hiệu lực
    final coupons = <CouponModel>[
      CouponModel(
        code: 'LINHKIEN150K',
        title: 'Giảm ngay 150.000 ₫ cho đơn từ 3.000.000 ₫',
        description: 'Áp dụng cho mọi linh kiện PC, Màn hình và ổ cứng SSD.',
        discountType: 'fixed',
        discountValue: 150000,
        minOrderAmount: 3000000,
        usageLimit: 500,
        usedCount: 24,
        startDate: now.subtract(const Duration(days: 5)),
        endDate: now.add(const Duration(days: 60)),
      ),
      CouponModel(
        code: 'DIY10',
        title: 'Giảm 10% tối đa 100.000 ₫ cho đơn từ 300.000 ₫',
        description: 'Ưu đãi dành cho sinh viên kỹ thuật mua linh kiện DIY, Arduino, cảm biến.',
        discountType: 'percentage',
        discountValue: 10,
        maxDiscountAmount: 100000,
        minOrderAmount: 300000,
        usageLimit: 1000,
        usedCount: 85,
        startDate: now.subtract(const Duration(days: 5)),
        endDate: now.add(const Duration(days: 60)),
      ),
    ];

    for (final coupon in coupons) {
      final ref =
      _firestore.collection(FirestoreCollections.coupons).doc(coupon.code);
      batch.set(ref, coupon.toFirestoreMap());
    }

    // 5. Seed Sản phẩm linh kiện thực tế (Giá VND kiểu int)
    final products = <ProductModel>[
      _buildSeedProduct(
        id: 'prod-cpu-i5-13400f',
        sku: 'CPU-INTEL-I5-13400F',
        name: 'Vi xử lý Intel Core i5-13400F (10 Nhân 16 Luồng, Up to 4.6GHz, LGA1700)',
        categoryId: 'cpu',
        parentCategoryId: 'pc-core',
        brandId: 'intel',
        brandName: 'Intel',
        model: 'Core i5-13400F',
        price: 5290000,
        salePrice: 4690000,
        stockQuantity: 35,
        thumbnailUrl: 'https://images.unsplash.com/photo-1591799264318-7e6ef8ddb7ea?w=800',
        shortDescription: 'CPU quốc dân cho cấu hình Gaming & Lập trình đa nhiệm, kiến trúc Raptor Lake.',
        description:
        'Intel Core i5-13400F sở hữu 6 nhân P-Core và 4 nhân E-Core (tổng cộng 10 nhân 16 luồng), bộ nhớ đệm 20MB Smart Cache, tương thích cả RAM DDR4 và DDR5 trên socket LGA1700.',
        specifications: const {
          'Socket': 'LGA1700',
          'Số nhân / Số luồng': '10 Nhân / 16 Luồng',
          'Xung nhịp Turbo': '4.6 GHz',
          'Bộ nhớ đệm': '20 MB Intel Smart Cache',
          'TDP cơ bản': '65W',
        },
        specFilterTags: const ['Socket:LGA1700', 'RAM:DDR5', 'RAM:DDR4'],
        warrantyMonths: 36,
        ratingAvg: 4.9,
        ratingCount: 42,
        soldCount: 185,
        isFeatured: true,
        isNew: false,
        createdAt: now.subtract(const Duration(days: 15)),
      ),
      _buildSeedProduct(
        id: 'prod-cpu-ryzen5-7600x',
        sku: 'CPU-AMD-R5-7600X',
        name: 'Vi xử lý AMD Ryzen 5 7600X (6 Nhân 12 Luồng, Up to 5.3GHz, Socket AM5)',
        categoryId: 'cpu',
        parentCategoryId: 'pc-core',
        brandId: 'amd',
        brandName: 'AMD',
        model: 'Ryzen 5 7600X',
        price: 5990000,
        salePrice: 5390000,
        stockQuantity: 22,
        thumbnailUrl: 'https://images.unsplash.com/photo-1555617778-02518510b9fa?w=800',
        shortDescription: 'Hiệu năng đơn nhân vượt trội kiến trúc Zen 4, tiến trình 5nm TSMC.',
        description:
        'AMD Ryzen 5 7600X mang lại xung nhịp boost lên đến 5.3 GHz, hỗ trợ PCIe 5.0 và bộ nhớ RAM DDR5 tốc độ cao trên nền tảng Socket AM5 bền bỉ.',
        specifications: const {
          'Socket': 'AM5',
          'Số nhân / Số luồng': '6 Nhân / 12 Luồng',
          'Xung nhịp Boost': '5.3 GHz',
          'Tiến trình': 'TSMC 5nm FinFET',
          'TDP': '105W',
        },
        specFilterTags: const ['Socket:AM5', 'RAM:DDR5'],
        warrantyMonths: 36,
        ratingAvg: 4.8,
        ratingCount: 28,
        soldCount: 112,
        isFeatured: true,
        isNew: true,
        createdAt: now.subtract(const Duration(days: 5)),
      ),
      _buildSeedProduct(
        id: 'prod-gpu-asus-rtx4060',
        sku: 'GPU-ASUS-DUAL-RTX4060-O8G',
        name: 'Card màn hình ASUS Dual GeForce RTX 4060 OC Edition 8GB GDDR6',
        categoryId: 'gpu',
        parentCategoryId: 'pc-core',
        brandId: 'asus',
        brandName: 'ASUS',
        model: 'DUAL-RTX4060-O8G',
        price: 8990000,
        salePrice: 8190000,
        stockQuantity: 18,
        thumbnailUrl: 'https://images.unsplash.com/photo-1587202372775-e229f172b9d7?w=800',
        shortDescription: 'Kiến trúc NVIDIA Ada Lovelace, DLSS 3, quạt Axial-tech tản nhiệt tối ưu.',
        description:
        'ASUS Dual RTX 4060 OC 8GB trang bị 2 quạt Axial-tech, tấm backplate kim loại bảo vệ PCB, tiêu thụ điện năng thấp chỉ yêu cầu nguồn 550W.',
        specifications: const {
          'GPU': 'NVIDIA GeForce RTX 4060',
          'VRAM': '8GB GDDR6',
          'Giao tiếp PCIe': 'PCIe 4.0 x8',
          'Cổng xuất hình': '1x HDMI 2.1a, 3x DisplayPort 1.4a',
          'Nguồn khuyến nghị': '550W (1x 8-pin)',
        },
        specFilterTags: const ['VRAM:8GB', 'GPU:RTX4060'],
        warrantyMonths: 36,
        ratingAvg: 4.9,
        ratingCount: 64,
        soldCount: 240,
        isFeatured: true,
        isNew: true,
        createdAt: now.subtract(const Duration(days: 3)),
      ),
      _buildSeedProduct(
        id: 'prod-ram-kingston-fury-32gb-ddr5',
        sku: 'RAM-KINGSTON-FURY-32GB-DDR5-6000',
        name: 'RAM Kingston Fury Beast RGB 32GB (2x16GB) DDR5 Bus 6000MHz CL36',
        categoryId: 'ram',
        parentCategoryId: 'pc-core',
        brandId: 'kingston',
        brandName: 'Kingston',
        model: 'KF560C36BBEAK2-32',
        price: 3490000,
        salePrice: 2990000,
        stockQuantity: 45,
        thumbnailUrl: 'https://images.unsplash.com/photo-1562976540-1502c2145186?w=800',
        shortDescription: 'Kit 32GB DDR5 hỗ trợ cả Intel XMP 3.0 và AMD EXPO, tản nhiệt nhôm RGB.',
        description:
        'Bộ nhớ RAM Kingston Fury Beast DDR5 32GB (2 thanh 16GB) mang lại băng thông 6000MT/s ổn định cho dàn PC làm việc đồ họa, chạy máy ảo và chơi game nặng.',
        specifications: const {
          'Dung lượng': '32GB (2 x 16GB)',
          'Chuẩn RAM': 'DDR5',
          'Bus RAM': '6000 MHz',
          'Độ trễ': 'CL36',
          'Điện áp': '1.35V',
        },
        specFilterTags: const ['RAM:DDR5', 'DungLuong:32GB'],
        warrantyMonths: 36,
        ratingAvg: 4.8,
        ratingCount: 51,
        soldCount: 310,
        isFeatured: true,
        isNew: false,
        createdAt: now.subtract(const Duration(days: 12)),
      ),
      _buildSeedProduct(
        id: 'prod-ssd-samsung-990pro-1tb',
        sku: 'SSD-SAMSUNG-990PRO-1TB-NVME',
        name: 'Ổ cứng SSD Samsung 990 PRO 1TB PCIe Gen 4.0 x4 NVMe M.2 2280',
        categoryId: 'ssd-hdd',
        parentCategoryId: 'pc-core',
        brandId: 'samsung',
        brandName: 'Samsung',
        model: 'MZ-V9P1T0BW',
        price: 3190000,
        salePrice: 2790000,
        stockQuantity: 50,
        thumbnailUrl: 'https://images.unsplash.com/photo-1597872200969-2b65d56bd16b?w=800',
        shortDescription: 'Tốc độ đọc 7450 MB/s, ghi 6900 MB/s, chuẩn M.2 NVMe PCIe 4.0 đỉnh cao.',
        description:
        'Samsung 990 PRO 1TB sử dụng NAND V-NAND TLC và bộ điều khiển In-house thế hệ mới, tối ưu tốc độ build project, load game và dựng video 4K.',
        specifications: const {
          'Dung lượng': '1 TB',
          'Chuẩn giao tiếp': 'M.2 NVMe PCIe Gen 4.0 x4',
          'Tốc độ đọc tuần tự': '7.450 MB/s',
          'Tốc độ ghi tuần tự': '6.900 MB/s',
          'Độ bền TBW': '600 TBW',
        },
        specFilterTags: const ['SSD:NVMeGen4', 'DungLuong:1TB'],
        warrantyMonths: 60,
        ratingAvg: 5.0,
        ratingCount: 89,
        soldCount: 420,
        isFeatured: true,
        isNew: false,
        createdAt: now.subtract(const Duration(days: 20)),
      ),
      _buildSeedProduct(
        id: 'prod-main-asus-b760m-plus',
        sku: 'MAIN-ASUS-TUF-B760M-PLUS-WIFI',
        name: 'Bo mạch chủ ASUS TUF Gaming B760M-PLUS WIFI II (LGA1700, DDR5, mATX)',
        categoryId: 'mainboard-psu',
        parentCategoryId: 'pc-core',
        brandId: 'asus',
        brandName: 'ASUS',
        model: 'TUF GAMING B760M-PLUS WIFI II',
        price: 4690000,
        salePrice: 4250000,
        stockQuantity: 28,
        thumbnailUrl: 'https://images.unsplash.com/photo-1518770660439-4636190af475?w=800',
        shortDescription: 'VRM 12+1+1 DrMOS, hỗ trợ CPU Intel Gen 12/13/14, Wi-Fi 6E & PCIe 5.0.',
        description:
        'Bo mạch chủ chuẩn quân đội TUF Gaming với dàn tản nhiệt VRM lớn, 3 khe M.2 PCIe 4.0, LAN 2.5Gb và Wi-Fi 6E tích hợp sẵn.',
        specifications: const {
          'Socket': 'LGA1700',
          'Kích thước': 'Micro-ATX (mATX)',
          'Khe RAM': '4 khe DDR5 (Tối đa 192GB)',
          'Khe M.2': '3 x M.2 PCIe 4.0',
          'Kết nối không dây': 'Wi-Fi 6E & Bluetooth 5.3',
        },
        specFilterTags: const ['Socket:LGA1700', 'RAM:DDR5'],
        warrantyMonths: 36,
        ratingAvg: 4.7,
        ratingCount: 33,
        soldCount: 150,
        isFeatured: false,
        isNew: true,
        createdAt: now.subtract(const Duration(days: 4)),
      ),
      _buildSeedProduct(
        id: 'prod-monitor-asus-tuf-vg279q3a',
        sku: 'MON-ASUS-VG279Q3A-27-180HZ',
        name: 'Màn hình Gaming ASUS TUF VG279Q3A 27 inch Fast IPS Full HD 180Hz 1ms',
        categoryId: 'monitors',
        parentCategoryId: 'peripherals-monitors',
        brandId: 'asus',
        brandName: 'ASUS',
        model: 'VG279Q3A',
        price: 4590000,
        salePrice: 3890000,
        stockQuantity: 16,
        thumbnailUrl: 'https://images.unsplash.com/photo-1527443224154-c4a3942d3acf?w=800',
        shortDescription: 'Tấm nền Fast IPS 99% sRGB, tần số quét 180Hz, G-Sync Compatible.',
        description:
        'Màn hình 27 inch viền mỏng chuyên game và làm việc, trang bị công nghệ ELMB Sync chống nhòe chuyển động và bảo vệ mắt Flicker-Free.',
        specifications: const {
          'Kích thước': '27 inch',
          'Tấm nền': 'Fast IPS',
          'Độ phân giải': '1920 x 1080 (FHD)',
          'Tần số quét': '180 Hz',
          'Độ phủ màu': '99% sRGB',
        },
        specFilterTags: const ['ManHinh:180Hz', 'ManHinh:IPS'],
        warrantyMonths: 36,
        ratingAvg: 4.8,
        ratingCount: 39,
        soldCount: 195,
        isFeatured: true,
        isNew: true,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      _buildSeedProduct(
        id: 'prod-diy-arduino-uno-r4-wifi',
        sku: 'DIY-ARDUINO-UNO-R4-WIFI',
        name: 'Bo mạch Arduino UNO R4 WiFi chính hãng (Renesas RA4M1 + ESP32-S3)',
        categoryId: 'arduino-mcu',
        parentCategoryId: 'diy-iot',
        brandId: 'arduino',
        brandName: 'Arduino',
        model: 'ABX00087',
        price: 790000,
        salePrice: 690000,
        stockQuantity: 80,
        thumbnailUrl: 'https://images.unsplash.com/photo-1553406830-ef2513450d76?w=800',
        shortDescription: 'Vi điều khiển ARM Cortex-M4 32-bit, tích hợp Wi-Fi/BLE ESP32-S3 và LED Matrix 12x8.',
        description:
        'Arduino UNO R4 WiFi nâng cấp mạnh mẽ từ dòng UNO R3 với chip Renesas RA4M1 48MHz, bộ nhớ Flash 256KB, SRAM 32KB, cổng USB-C và kết nối IoT đám mây.',
        specifications: const {
          'Vi điều khiển chính': 'Renesas RA4M1 (ARM Cortex-M4)',
          'Module không dây': 'ESP32-S3-MINI-1 (Wi-Fi & Bluetooth)',
          'Bộ nhớ': '256 KB Flash / 32 KB SRAM',
          'Điện áp hoạt động': '5V (Cấp nguồn USB-C hoặc Vin 6-24V)',
          'Tính năng đặc biệt': 'Ma trận 96 bóng LED đỏ 12x8 trên mạch',
        },
        specFilterTags: const ['DIY:Arduino', 'DIY:WiFi'],
        warrantyMonths: 12,
        ratingAvg: 4.9,
        ratingCount: 74,
        soldCount: 530,
        isFeatured: true,
        isNew: true,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      _buildSeedProduct(
        id: 'prod-diy-sensor-kit-37in1',
        sku: 'DIY-SENSOR-KIT-37IN1-BOX',
        name: 'Bộ Kit 37 Cảm biến thông dụng cho Arduino, ESP32, Raspberry Pi (Kèm hộp nhựa)',
        categoryId: 'sensors-ic',
        parentCategoryId: 'diy-iot',
        brandId: 'arduino',
        brandName: 'Arduino',
        model: 'SENSOR-37-KIT',
        price: 380000,
        salePrice: 320000,
        stockQuantity: 120,
        thumbnailUrl: 'https://images.unsplash.com/photo-1517077304055-6e89abbf09b0?w=800',
        shortDescription: 'Bao gồm cảm biến nhiệt độ DHT11, siêu âm, hồng ngoại, relay, joystick, âm thanh...',
        description:
        'Bộ 37 module cảm biến và linh kiện điện tử DIY thiết yếu cho đồ án môn học IoT, hệ thống nhúng và tự động hóa trong nhà thông minh.',
        specifications: const {
          'Số lượng module': '37 module cảm biến & chấp hành',
          'Điện áp tương thích': '3.3V - 5V DC',
          'Vi điều khiển hỗ trợ': 'Arduino, ESP8266, ESP32, STM32, Raspberry Pi',
          'Phụ kiện đi kèm': 'Hộp nhựa chia ngăn chống tĩnh điện',
        },
        specFilterTags: const ['DIY:Arduino', 'DIY:CamBien'],
        warrantyMonths: 6,
        ratingAvg: 4.8,
        ratingCount: 92,
        soldCount: 610,
        isFeatured: false,
        isNew: false,
        createdAt: now.subtract(const Duration(days: 25)),
      ),
    ];

    for (final product in products) {
      final ref = _firestore
          .collection(FirestoreCollections.products)
          .doc(product.id);
      batch.set(ref, product.toFirestoreMap());
    }

    // 6. Seed Đánh giá thực tế cho sản phẩm mẫu
    final sampleReview = ReviewModel(
      id: 'seed_order_1_prod-cpu-i5-13400f',
      productId: 'prod-cpu-i5-13400f',
      orderId: 'seed_order_1',
      userId: 'seed_customer',
      userName: 'Nguyễn Minh Hoàng',
      rating: 5,
      comment:
      'CPU nguyên seal hộp chính hãng, lắp lên main B760M chạy mát, build Flutter và Android Emulator cực nhanh.',
      status: 'approved',
      adminReply:
      'Cảm ơn bạn đã tin tưởng mua sắm linh kiện tại Electronic Store!',
      createdAt: now.subtract(const Duration(days: 2)),
    );
    batch.set(
      _firestore.collection(FirestoreCollections.reviews).doc(sampleReview.id),
      sampleReview.toFirestoreMap(),
    );

    await batch.commit();
  }

  ProductModel _buildSeedProduct({
    required String id,
    required String sku,
    required String name,
    required String categoryId,
    required String parentCategoryId,
    required String brandId,
    required String brandName,
    required String model,
    required int price,
    int? salePrice,
    required int stockQuantity,
    required String thumbnailUrl,
    required String shortDescription,
    required String description,
    required Map<String, String> specifications,
    required List<String> specFilterTags,
    required int warrantyMonths,
    required double ratingAvg,
    required int ratingCount,
    required int soldCount,
    required bool isFeatured,
    required bool isNew,
    required DateTime createdAt,
  }) {
    final effectivePrice = salePrice ?? price;
    return ProductModel(
      id: id,
      sku: sku,
      name: name,
      nameLower: name.toLowerCase(),
      searchKeywords: ProductModel.generateSearchKeywords(
        name: name,
        sku: sku,
        brandName: brandName,
        model: model,
      ),
      categoryId: categoryId,
      parentCategoryId: parentCategoryId,
      brandId: brandId,
      brandName: brandName,
      model: model,
      price: price,
      salePrice: salePrice,
      effectivePrice: effectivePrice,
      stockQuantity: stockQuantity,
      reservedQuantity: 0,
      availableStock: stockQuantity,
      inStock: stockQuantity > 0,
      thumbnailUrl: thumbnailUrl,
      imageUrls: <String>[thumbnailUrl],
      shortDescription: shortDescription,
      description: description,
      specifications: specifications,
      specFilterTags: specFilterTags,
      warrantyMonths: warrantyMonths,
      ratingAvg: ratingAvg,
      ratingCount: ratingCount,
      soldCount: soldCount,
      isFeatured: isFeatured,
      isNew: isNew,
      isOnSale: salePrice != null && salePrice < price,
      isActive: true,
      isDeleted: false,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }
}