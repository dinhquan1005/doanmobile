import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/admin/screens/admin_dashboard_screen.dart';
import '../features/admin/screens/admin_product_form_screen.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/cart/screens/cart_screen.dart';
import '../features/categories/screens/categories_screen.dart';
import '../features/checkout/screens/checkout_screen.dart';
import '../features/favorites/screens/favorites_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/main_shell/main_shell_screen.dart';
import '../features/orders/screens/order_detail_screen.dart';
import '../features/orders/screens/orders_list_screen.dart';
import '../features/products/screens/product_detail_screen.dart';
import '../features/search/screens/catalog_search_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// [VẤN ĐÁP] Provider cấu hình hệ thống điều hướng toàn ứng dụng (GoRouter)
/// - Quản lý cây điều hướng phân cấp (Root Navigator & Shell Navigator).
/// - Tự động tái tính toán điều hướng khi `currentUserProfileProvider` thay đổi (Reactive Auth Redirect).
final appRouterProvider = Provider<GoRouter>((ref) {
  final userProfileAsync = ref.watch(currentUserProfileProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    /// [VẤN ĐÁP] Bộ bảo vệ tuyến đường (Route Guards / Redirect Logic)
    /// - Bảo vệ 1: Người dùng đã đăng nhập thì không được vào lại trang Đăng nhập / Đăng ký.
    /// - Bảo vệ 2: Chưa đăng nhập mà truy cập `/checkout` thì chuyển hướng bắt buộc đăng nhập.
    /// - Bảo vệ 3: Phân quyền quản trị - Không có quyền `isStaffOrAdmin` mà vào `/admin` thì lập tức bị chặn.
    redirect: (BuildContext context, GoRouterState state) {
      final user = userProfileAsync.valueOrNull;
      final isLoggedIn = user != null;
      final path = state.uri.path;

      final isAuthRoute = path == '/login' ||
          path == '/register' ||
          path == '/forgot-password';

      if (isLoggedIn && isAuthRoute) {
        return '/';
      }

      if (path == '/checkout' && !isLoggedIn) {
        return '/login';
      }

      if (path.startsWith('/admin') && (user == null || !user.isStaffOrAdmin)) {
        return '/login';
      }

      return null;
    },
    routes: [
      /// [VẤN ĐÁP] StatefulShellRoute.indexedStack: Giữ nguyên trạng thái (Preserve State)
      /// Giúp 5 tab đáy (Trang chủ, Danh mục, Giỏ hàng, Đơn hàng, Tài khoản) không bị rebuild/mất dữ liệu khi bấm chuyển qua lại.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShellScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/categories',
                builder: (context, state) => const CategoriesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/cart',
                builder: (context, state) => const CartScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/orders',
                builder: (context, state) => const OrdersListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/account',
                builder: (context, state) => const AccountTabScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/search',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CatalogSearchScreen(),
      ),
      GoRoute(
        path: '/products/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final productId = state.pathParameters['id'] ?? '';
          return ProductDetailScreen(productId: productId);
        },
      ),
      GoRoute(
        path: '/favorites',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const FavoritesScreen(),
      ),
      GoRoute(
        path: '/checkout',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: '/orders/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final orderId = state.pathParameters['id'] ?? '';
          return OrderDetailScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: '/login',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/admin',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/products/add',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AdminProductFormScreen(),
      ),
    ],
  );
});