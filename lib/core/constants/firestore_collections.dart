
class FirestoreCollections {
  FirestoreCollections._();

  static const String users = 'users';
  static const String addressesSubcollection = 'addresses';
  static const String categories = 'categories';
  static const String brands = 'brands';
  static const String products = 'products';
  static const String carts = 'carts';
  static const String orders = 'orders';
  static const String orderIdempotency = 'order_idempotency';
  static const String reviews = 'reviews';
  static const String favorites = 'favorites';
  static const String coupons = 'coupons';
  static const String banners = 'banners';
  static const String notifications = 'notifications';
  static const String inventoryTransactions = 'inventory_transactions';
  static const String appSettings = 'app_settings';

  /// Document ID cố định trong collection app_settings
  static const String publicConfigDocId = 'public_config';
}