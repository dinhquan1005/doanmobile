import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/constants/firestore_collections.dart';
import '../../core/errors/app_failure.dart';
import '../models/user_model.dart';

class AuthRepository {
  AuthRepository({
    required FirebaseAuth firebaseAuth,
    required FirebaseFirestore firestore,
    GoogleSignIn? googleSignIn,
  })  : _firebaseAuth = firebaseAuth,
        _firestore = firestore,
        _googleSignIn = googleSignIn;

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn? _googleSignIn;

  /// [VẤN ĐÁP] Lắng nghe thay đổi trạng thái phiên xác thực (Logged In / Logged Out)
  /// Trả về `Stream<User?>` từ Firebase Auth để UI tự động cập nhật khi người dùng đăng nhập hoặc đăng xuất.
  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  /// [VẤN ĐÁP] Lấy thông tin user hiện tại đang đăng nhập trực tiếp từ bộ nhớ đệm Firebase Auth
  User? get currentFirebaseUser => _firebaseAuth.currentUser;

  /// [VẤN ĐÁP] Đọc Custom Claims từ ID Token để xác định quyền Admin/Staff chính xác từ máy chủ
  /// - Mục đích: Bảo mật phía server. Client không thể tự ý sửa role trong Firestore để chiếm quyền Admin.
  /// - forceRefresh: Ép Firebase làm mới JWT Token để nhận quyền mới nhất nếu vừa được cấp quyền.
  Future<UserRole> getClaimRole(User user, {bool forceRefresh = false}) async {
    try {
      final idTokenResult = await user.getIdTokenResult(forceRefresh);
      final claimRole = idTokenResult.claims?['role'] as String?;
      return UserRole.fromString(claimRole);
    } catch (_) {
      return UserRole.customer;
    }
  }

  /// [VẤN ĐÁP] Lắng nghe hồ sơ người dùng thời gian thực (Real-time Stream) từ Firestore kết hợp Claims
  /// - Sử dụng `asyncExpand` để chuyển đổi từ Stream Firebase User sang Stream UserModel
  /// - Tự động đồng bộ khi thông tin họ tên, số điện thoại, avatar trong Firestore thay đổi.
  Stream<UserModel?> watchCurrentUserProfile() {
    return _firebaseAuth.authStateChanges().asyncExpand((User? user) async* {
      if (user == null) {
        yield null;
        return;
      }
      final claimRole = await getClaimRole(user);
      final userDocRef =
      _firestore.collection(FirestoreCollections.users).doc(user.uid);

      yield* userDocRef.snapshots().map((snapshot) {
        if (!snapshot.exists) {
          final now = DateTime.now().toUtc();
          return UserModel(
            id: user.uid,
            email: user.email ?? '',
            fullName: user.displayName?.trim().isNotEmpty == true
                ? user.displayName!.trim()
                : 'Khách hàng',
            avatarUrl: user.photoURL,
            role: claimRole,
            createdAt: now,
            updatedAt: now,
          );
        }
        final effectiveRole =
        claimRole != UserRole.customer ? claimRole : null;
        return UserModel.fromFirestore(
          snapshot,
          claimRoleOverride: effectiveRole,
        );
      });
    });
  }

  /// [VẤN ĐÁP] Đăng nhập bằng tài khoản Email & Mật khẩu
  /// - Bước 1: Gọi `signInWithEmailAndPassword` của Firebase Auth để kiểm tra thông tin đăng nhập.
  /// - Bước 2: Gọi `_ensureUserDocument` để lấy thông tin hồ sơ tương ứng từ Firestore.
  Future<UserModel> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthFailure(
          message: 'Không thể lấy thông tin phiên đăng nhập.',
        );
      }
      return await _ensureUserDocument(user);
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    }
  }

  /// [VẤN ĐÁP] Đăng ký tài khoản người dùng mới
  /// - Bước 1: Tạo tài khoản trên Firebase Authentication bằng `createUserWithEmailAndPassword`.
  /// - Bước 2: Cập nhật `displayName` trên Auth Profile.
  /// - Bước 3: Tạo document mới lưu vào Firestore collection `users/{uid}`.
  Future<UserModel> registerWithEmailAndPassword({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthFailure(message: 'Đăng ký tài khoản thất bại.');
      }

      await user.updateDisplayName(fullName.trim());
      return await _ensureUserDocument(
        user,
        fullNameOverride: fullName.trim(),
        phoneOverride: phoneNumber.trim(),
      );
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    }
  }

  /// [VẤN ĐÁP] Đăng nhập bằng Google (OAuth 2.0)
  /// - Bước 1: Mở hộp thoại Google Sign-In trên thiết bị để người dùng chọn tài khoản Google.
  /// - Bước 2: Nhận `idToken` và `accessToken` từ tài khoản Google.
  /// - Bước 3: Đổi Google Auth Credential lấy Firebase User Credential thông qua `signInWithCredential`.
  /// - Bước 4: Đồng bộ hồ sơ tài khoản Google vào Firestore.
  Future<UserModel> signInWithGoogle() async {
    try {
      final googleClient = _googleSignIn ??
          GoogleSignIn(
            serverClientId:
                '383448578264-g0u1cu53r4dg8tp8pp7oi9tm3ml8cm8r.apps.googleusercontent.com',
          );
      final googleUser = await googleClient.signIn();
      if (googleUser == null) {
        throw const AuthFailure(
          message: 'Bạn đã hủy đăng nhập bằng Google.',
          code: 'google-sign-in-cancelled',
        );
      }

      final googleAuth = await googleUser.authentication;
      final oauthCredential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await _firebaseAuth.signInWithCredential(oauthCredential);
      final user = userCredential.user;
      if (user == null) {
        throw const AuthFailure(message: 'Đăng nhập Google thất bại.');
      }

      return await _ensureUserDocument(user);
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } on PlatformException catch (e) {
      String message = e.message ?? 'Đăng nhập Google thất bại (${e.code}).';
      final details = '${e.message} ${e.details}';
      if (details.contains('12500')) {
        message =
            'Đăng nhập Google chưa hoàn tất (Mã 12500). Vui lòng cấu hình Email hỗ trợ trong Firebase Console hoặc khởi động lại ứng dụng.';
      } else if (details.contains('12501') || e.code == 'sign_in_canceled') {
        message = 'Bạn đã hủy đăng nhập bằng Google.';
      } else if (details.contains('10')) {
        message =
            'Lỗi chữ ký ứng dụng (Mã 10). Vui lòng kiểm tra mã SHA-1 của thiết bị trên Firebase.';
      } else if (details.contains('7') || details.contains('network_error')) {
        message =
            'Mất kết nối mạng khi liên kết với tài khoản Google. Vui lòng kiểm tra Internet.';
      }
      throw AuthFailure(
        message: message,
        code: e.code,
      );
    }
  }

  /// [VẤN ĐÁP] Gửi email đặt lại mật khẩu cho người dùng
  /// Firebase Authentication sẽ gửi một liên kết an toàn tới email được chỉ định.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    }
  }

  /// [VẤN ĐÁP] Đăng xuất người dùng
  /// Hủy phiên trên cả Google Sign-In (nếu có) và Firebase Authentication.
  Future<void> signOut() async {
    try {
      final googleClient = _googleSignIn;
      if (googleClient != null) {
        await googleClient.signOut();
      }
    } catch (_) {
      // Bỏ qua nếu người dùng không đăng nhập bằng Google
    }
    await _firebaseAuth.signOut();
  }

  /// [VẤN ĐÁP] Khởi tạo hoặc đồng bộ Document người dùng trong Cloud Firestore
  /// - Khi người dùng đăng nhập lần đầu (qua Google hoặc Email), hàm kiểm tra document `users/{uid}`.
  /// - Nếu chưa tồn tại: Tạo document mới với vai trò mặc định là `customer` (hoặc `admin` nếu là email quản trị viên mặc định).
  /// - Nếu đã tồn tại: Đọc thông tin và kiểm tra xem tài khoản có bị khóa (`isBlocked`) hay không.
  Future<UserModel> _ensureUserDocument(
      User user, {
        String? fullNameOverride,
        String? phoneOverride,
      }) async {
    final docRef =
    _firestore.collection(FirestoreCollections.users).doc(user.uid);
    final snapshot = await docRef.get();
    final claimRole = await getClaimRole(user);

    if (!snapshot.exists) {
      final now = DateTime.now().toUtc();
      final userEmail = (user.email ?? '').toLowerCase().trim();
      final isDefaultAdmin = userEmail.startsWith('admin@') || userEmail == 'admin@electronicstore.vn';
      final defaultRole = isDefaultAdmin ? UserRole.admin : UserRole.customer;

      final newUser = UserModel(
        id: user.uid,
        email: user.email ?? '',
        fullName: fullNameOverride ??
            (user.displayName?.trim().isNotEmpty == true
                ? user.displayName!.trim()
                : (isDefaultAdmin ? 'Quản trị viên' : 'Khách hàng')),
        phoneNumber: phoneOverride,
        avatarUrl: user.photoURL,
        role: defaultRole,
        isBlocked: false,
        createdAt: now,
        updatedAt: now,
      );
      await docRef.set(newUser.toFirestoreCreateMap());
      return newUser.copyWith(role: claimRole != UserRole.customer ? claimRole : defaultRole);
    }

    final existingUser = UserModel.fromFirestore(
      snapshot,
      claimRoleOverride:
      claimRole != UserRole.customer ? claimRole : null,
    );

    if (existingUser.isBlocked) {
      await _firebaseAuth.signOut();
      throw const AuthFailure(
        message: 'Tài khoản của bạn đã bị khóa. Vui lòng liên hệ CSKH.',
        code: 'user-blocked',
      );
    }

    return existingUser;
  }

  /// Tiện ích hỗ trợ học tập & kiểm thử:
  /// Cho phép đổi quyền giữa Customer và Admin để test trực tiếp trên UI
  Future<void> updateUserRoleForTesting({
    required String userId,
    required UserRole newRole,
  }) async {
    await _firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .update({
      'role': newRole.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  AuthFailure _mapFirebaseAuthException(FirebaseAuthException e) {
    final message = switch (e.code) {
      'user-not-found' ||
      'invalid-credential' ||
      'wrong-password' =>
      'Email hoặc mật khẩu không chính xác.',
      'email-already-in-use' =>
      'Địa chỉ email này đã được đăng ký cho tài khoản khác.',
      'invalid-email' => 'Địa chỉ email không hợp lệ.',
      'weak-password' => 'Mật khẩu quá yếu (tối thiểu 6 ký tự).',
      'user-disabled' => 'Tài khoản này đã bị vô hiệu hóa.',
      'too-many-requests' =>
      'Quá nhiều yêu cầu liên tiếp. Vui lòng thử lại sau ít phút.',
      'network-request-failed' =>
      'Mất kết nối mạng. Vui lòng kiểm tra Internet của bạn.',
      _ => e.message ?? 'Đã xảy ra lỗi xác thực (${e.code}).',
    };
    return AuthFailure(message: message, code: e.code);
  }
}