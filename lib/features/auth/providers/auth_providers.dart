import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    firebaseAuth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
    googleSignIn: ref.watch(googleSignInProvider),
  );
});

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final currentUserProfileProvider = StreamProvider<UserModel?>((ref) {
  return ref.watch(authRepositoryProvider).watchCurrentUserProfile();
});

class AuthActionState {
  const AuthActionState({
    this.isLoading = false,
    this.errorMessage,
    this.infoMessage,
  });

  final bool isLoading;
  final String? errorMessage;
  final String? infoMessage;

  AuthActionState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? infoMessage,
  }) {
    return AuthActionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      infoMessage: infoMessage,
    );
  }
}

class AuthController extends StateNotifier<AuthActionState> {
  AuthController(this._repository) : super(const AuthActionState());

  final AuthRepository _repository;

  void clearMessages() {
    state = state.copyWith(errorMessage: null, infoMessage: null);
  }

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AuthActionState(isLoading: true);
    try {
      await _repository.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      state = const AuthActionState(isLoading: false);
      return true;
    } on AppFailure catch (e) {
      state = AuthActionState(isLoading: false, errorMessage: e.message);
      return false;
    } catch (_) {
      state = const AuthActionState(
        isLoading: false,
        errorMessage: 'Đã xảy ra lỗi không xác định khi đăng nhập.',
      );
      return false;
    }
  }

  Future<bool> registerWithEmail({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    state = const AuthActionState(isLoading: true);
    try {
      await _repository.registerWithEmailAndPassword(
        fullName: fullName,
        email: email,
        phoneNumber: phoneNumber,
        password: password,
      );
      state = const AuthActionState(isLoading: false);
      return true;
    } on AppFailure catch (e) {
      state = AuthActionState(isLoading: false, errorMessage: e.message);
      return false;
    } catch (_) {
      state = const AuthActionState(
        isLoading: false,
        errorMessage: 'Không thể hoàn tất đăng ký tài khoản.',
      );
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    state = const AuthActionState(isLoading: true);
    try {
      await _repository.signInWithGoogle();
      state = const AuthActionState(isLoading: false);
      return true;
    } on AppFailure catch (e) {
      state = AuthActionState(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = AuthActionState(
        isLoading: false,
        errorMessage:
            'Đăng nhập Google thất bại: $e',
      );
      return false;
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    state = const AuthActionState(isLoading: true);
    try {
      await _repository.sendPasswordResetEmail(email);
      state = const AuthActionState(
        isLoading: false,
        infoMessage:
        'Liên kết đặt lại mật khẩu đã được gửi tới email của bạn.',
      );
      return true;
    } on AppFailure catch (e) {
      state = AuthActionState(isLoading: false, errorMessage: e.message);
      return false;
    }
  }

  Future<bool> toggleUserRoleForTesting(UserModel currentUser) async {
    final newRole = currentUser.isAdmin ? UserRole.customer : UserRole.admin;
    state = const AuthActionState(isLoading: true);
    try {
      await _repository.updateUserRoleForTesting(
        userId: currentUser.id,
        newRole: newRole,
      );
      state = AuthActionState(
        isLoading: false,
        infoMessage: 'Đã chuyển sang vai trò: ${newRole.name.toUpperCase()}',
      );
      return true;
    } catch (e) {
      state = AuthActionState(
        isLoading: false,
        errorMessage: 'Không thể chuyển vai trò: $e',
      );
      return false;
    }
  }

  Future<void> signOut() async {
    state = const AuthActionState(isLoading: true);
    await _repository.signOut();
    state = const AuthActionState(isLoading: false);
  }
}

final authControllerProvider =
StateNotifierProvider<AuthController, AuthActionState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});