import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/theme_mode_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/state_views.dart';
import '../auth/providers/auth_providers.dart';
import '../cart/providers/cart_providers.dart';
import '../favorites/providers/favorites_providers.dart';

class MainShellScreen extends ConsumerWidget {
const MainShellScreen({
super.key,
required this.navigationShell,
});

final StatefulNavigationShell navigationShell;

void _onTapBranch(int index) {
navigationShell.goBranch(
index,
initialLocation: index == navigationShell.currentIndex,
);
}

@override
Widget build(BuildContext context, WidgetRef ref) {
final cartCount = ref.watch(cartTotalItemCountProvider);

return Scaffold(
body: navigationShell,
bottomNavigationBar: NavigationBar(
selectedIndex: navigationShell.currentIndex,
onDestinationSelected: _onTapBranch,
destinations: [
const NavigationDestination(
icon: Icon(Icons.home_outlined),
selectedIcon: Icon(Icons.home_rounded),
label: 'Trang chủ',
),
const NavigationDestination(
icon: Icon(Icons.category_outlined),
selectedIcon: Icon(Icons.category_rounded),
label: 'Danh mục',
),
NavigationDestination(
icon: Badge(
isLabelVisible: cartCount > 0,
label: Text('$cartCount'),
child: const Icon(Icons.shopping_cart_outlined),
),
selectedIcon: Badge(
isLabelVisible: cartCount > 0,
label: Text('$cartCount'),
child: const Icon(Icons.shopping_cart_rounded),
),
label: 'Giỏ hàng',
),
const NavigationDestination(
icon: Icon(Icons.receipt_long_outlined),
selectedIcon: Icon(Icons.receipt_long_rounded),
label: 'Đơn hàng',
),
const NavigationDestination(
icon: Icon(Icons.person_outline_rounded),
selectedIcon: Icon(Icons.person_rounded),
label: 'Tài khoản',
),
],
),
);
}
}

class TabPlaceholderScreen extends StatelessWidget {
const TabPlaceholderScreen({
super.key,
required this.title,
required this.subtitle,
required this.icon,
});

final String title;
final String subtitle;
final IconData icon;

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
title: Text(title),
),
body: Center(
child: Padding(
padding: const EdgeInsets.all(24),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Icon(
icon,
size: 56,
color: Theme.of(context).colorScheme.primary,
),
const SizedBox(height: 16),
Text(
title,
style: Theme.of(context).textTheme.titleLarge?.copyWith(
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 8),
Text(
subtitle,
textAlign: TextAlign.center,
),
],
),
),
),
);
}
}

class AccountTabScreen extends ConsumerWidget {
const AccountTabScreen({super.key});

@override
Widget build(BuildContext context, WidgetRef ref) {
final userProfileAsync = ref.watch(currentUserProfileProvider);
final themeMode = ref.watch(themeModeProvider);
final favCount = ref.watch(favoritesControllerProvider).length;

return Scaffold(
appBar: AppBar(
title: const Text('Tài khoản & Cài đặt'),
actions: [
IconButton(
tooltip: 'Đổi giao diện Sáng/Tối',
onPressed: () {
ref.read(themeModeProvider.notifier).toggleLightDark();
},
icon: Icon(
themeMode == ThemeMode.dark
? Icons.light_mode_rounded
    : Icons.dark_mode_rounded,
),
),
],
),
body: userProfileAsync.when(
loading: () => const Center(child: CircularProgressIndicator()),
error: (err, _) => EmptyOrErrorState(
icon: Icons.lock_outline_rounded,
title: 'Không thể tải hồ sơ từ Cloud Firestore',
message:
'Vui lòng bấm Publish Firestore Rules trên Firebase Console rồi nhấn Thử lại.\nChi tiết: $err',
actionLabel: 'Thử lại',
onAction: () => ref.invalidate(currentUserProfileProvider),
secondaryActionLabel: 'Đăng xuất phiên hiện tại',
onSecondaryAction: () async {
await ref.read(authControllerProvider.notifier).signOut();
},
),
data: (user) {
if (user == null) {
return ListView(
padding: const EdgeInsets.all(20),
children: [
Card(
child: Padding(
padding: const EdgeInsets.all(24),
child: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.stretch,
children: [
Icon(
Icons.account_circle_outlined,
size: 64,
color: Theme.of(context).colorScheme.primary,
),
const SizedBox(height: 12),
Text(
'Chào mừng đến với ${AppConstants.appName}',
textAlign: TextAlign.center,
style: Theme.of(context)
    .textTheme
    .titleMedium
    ?.copyWith(fontWeight: FontWeight.bold),
),
const SizedBox(height: 8),
const Text(
'Đăng nhập để đồng bộ giỏ hàng, danh sách yêu thích, áp dụng mã giảm giá và theo dõi bảo hành linh kiện.',
textAlign: TextAlign.center,
),
const SizedBox(height: 20),
FilledButton(
key: const Key('open_login_button'),
onPressed: () => context.push('/login'),
child: const Text('Đăng nhập'),
),
const SizedBox(height: 10),
OutlinedButton(
key: const Key('open_register_button'),
onPressed: () => context.push('/register'),
child: const Text('Tạo tài khoản mới'),
),
],
),
),
),
const SizedBox(height: 12),
Card(
child: ListTile(
key: const Key('open_favorites_button'),
leading: const Icon(
Icons.favorite_rounded,
color: Colors.redAccent,
),
title: const Text('Sản phẩm yêu thích'),
subtitle: Text('Đang lưu $favCount linh kiện trên thiết bị'),
trailing: const Icon(Icons.chevron_right),
onTap: () => context.push('/favorites'),
),
),
],
);
}

return ListView(
padding: const EdgeInsets.all(16),
children: [
Card(
child: ListTile(
leading: CircleAvatar(
backgroundColor:
Theme.of(context).colorScheme.primaryContainer,
child: Text(
user.fullName.isNotEmpty
? user.fullName[0].toUpperCase()
    : 'U',
style: const TextStyle(fontWeight: FontWeight.bold),
),
),
title: Text(
user.fullName,
style: const TextStyle(fontWeight: FontWeight.bold),
),
subtitle: Text(
'${user.email}\nSĐT: ${user.phoneNumber ?? "Chưa cập nhật"}',
),
isThreeLine: true,
),
),
const SizedBox(height: 12),
Card(
child: ListTile(
key: const Key('open_favorites_button'),
leading: const Icon(
Icons.favorite_rounded,
color: Colors.redAccent,
),
title: const Text('Danh sách sản phẩm yêu thích'),
subtitle: Text('$favCount sản phẩm đã lưu đồng bộ'),
trailing: const Icon(Icons.chevron_right),
onTap: () => context.push('/favorites'),
),
),
const SizedBox(height: 12),
if (user.isStaffOrAdmin)
Card(
child: ListTile(
leading: const Icon(Icons.admin_panel_settings_rounded),
title: const Text('Khu vực Quản trị (Admin Panel)'),
subtitle:
Text('Quyền hiện tại: ${user.role.name.toUpperCase()}'),
trailing: const Icon(Icons.chevron_right),
onTap: () => context.push('/admin'),
),
),
Card(
child: SwitchListTile(
secondary: const Icon(Icons.shield_outlined, color: Colors.deepPurple),
title: const Text('Chế độ Quản trị viên'),
subtitle: Text(
user.isAdmin
? 'Tài khoản có quyền Quản trị viên'
: 'Tài khoản Khách hàng thông thường',
style: const TextStyle(fontSize: 12),
),
value: user.isAdmin,
onChanged: (_) async {
await ref
.read(authControllerProvider.notifier)
.toggleUserRoleForTesting(user);
},
),
),
Card(
child: Column(
children: [
SwitchListTile(
secondary: const Icon(Icons.dark_mode_outlined),
title: const Text('Giao diện tối (Dark Mode)'),
value: themeMode == ThemeMode.dark,
onChanged: (isDark) {
ref.read(themeModeProvider.notifier).setThemeMode(
isDark ? ThemeMode.dark : ThemeMode.light,
);
},
),
const Divider(height: 1),
ListTile(
key: const Key('logout_button'),
leading: Icon(
Icons.logout_rounded,
color: Theme.of(context).colorScheme.error,
),
title: Text(
'Đăng xuất',
style: TextStyle(
color: Theme.of(context).colorScheme.error,
fontWeight: FontWeight.w600,
),
),
onTap: () async {
await ref
    .read(authControllerProvider.notifier)
    .signOut();
},
),
],
),
),
],
);
},
),
);
}
}