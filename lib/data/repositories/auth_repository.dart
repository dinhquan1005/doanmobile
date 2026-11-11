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

  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  User? get currentFirebaseUser => _firebaseAuth.currentUser;

  Future<UserRole> getClaimRole(User user, {bool forceRefresh = false}) async {
    try {
      final idTokenResult = await user.getIdTokenResult(forceRefresh);
      final claimRole = idTokenResult.claims?['role'] as String?;
      return UserRole.fromString(claimRole);
    } catch (_) {
      return UserRole.customer;
    }
  }

  Stream<UserModel?> watchCurrentUserProfile() {
    return _firebaseAuth.authStateChanges().asyncExpand((User? user) async* {
      if (user == null) {
        yield null;
        return;
      }
      final claimRole = await getClaimRole(user);
      final userDocRef =
      _firestore.collection(FirestoreCollections.users).doc(user.uid);

      Stream<UserModel> profileStream() async* {
        try {
          await for (final snapshot in userDocRef.snapshots()) {
            if (!snapshot.exists) {
              final now = DateTime.now().toUtc();
              yield UserModel(
                id: user.uid,
                email: user.email ?? '',
                fullName: user.displayName?.trim().isNotEmpty == true
                    ? user.displayName!.trim()
                    : (user.email != null && user.email!.contains('@')
                        ? user.email!.split('@').first
                        : 'Khách hàng'),
                avatarUrl: user.photoURL,
                role: claimRole,
                createdAt: now,
                updatedAt: now,
              );
            } else {
              final effectiveRole =
                  claimRole != UserRole.customer ? claimRole : null;
              yield UserModel.fromFirestore(
                snapshot,
                claimRoleOverride: effectiveRole,
              );
            }
          }
        } catch (_) {
          final now = DateTime.now().toUtc();
          yield UserModel(
            id: user.uid,
            email: user.email ?? '',
            fullName: user.displayName?.trim().isNotEmpty == true
                ? user.displayName!.trim()
                : (user.email != null && user.email!.contains('@')
                    ? user.email!.split('@').first
                    : 'Khách hàng'),
            avatarUrl: user.photoURL,
            role: claimRole,
            createdAt: now,
            updatedAt: now,
          );
        }
      }
      yield* profileStream();
    });
  }

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

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    }
  }

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