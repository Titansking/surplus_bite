import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? error;

  const AuthState({this.status = AuthStatus.initial, this.user, this.error});

  AuthState copyWith({AuthStatus? status, UserModel? user, String? error}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final FirestoreService _firestoreService;

  AuthNotifier(this._authService, this._firestoreService)
    : super(const AuthState()) {
    _init();
  }

  void _init() {
    _authService.authStateChanges.listen((user) async {
      try {
        if (user != null) {
          debugPrint('AUTH: user != null, fetching profile for ${user.uid}');
          var userModel = await _firestoreService
              .getUserProfile(user.uid)
              .timeout(const Duration(seconds: 10));

          if (userModel == null) {
            final now = DateTime.now();
            userModel = UserModel(
              id: user.uid,
              name: user.displayName ?? user.email?.split('@').first ?? 'User',
              email: user.email ?? '',
              role: 'consumer',
              profileImage: user.photoURL,
              createdAt: now,
              updatedAt: now,
            );
            await _authService.createFirestoreUser(userModel);
          }

          debugPrint('AUTH: profile fetched: true');
          state = AuthState(status: AuthStatus.authenticated, user: userModel);
        } else {
          debugPrint('AUTH: user == null');
          state = const AuthState(status: AuthStatus.unauthenticated);
        }
      } catch (e) {
        debugPrint('AUTH: error $e');
        state = AuthState(status: AuthStatus.error, error: e.toString());
      }
    });
  }

  Future<void> signIn(String email, String password) async {
    debugPrint('SIGNIN: starting for $email');
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _authService.signInWithEmail(email, password);
      debugPrint('SIGNIN: signInWithEmail completed');
    } catch (e) {
      debugPrint('SIGNIN: error $e');
      state = AuthState(status: AuthStatus.error, error: e.toString());
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final credential = await _authService.signInWithGoogle();
      if (credential == null) {
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }
    } catch (e) {
      state = AuthState(status: AuthStatus.error, error: e.toString());
    }
  }

  Future<void> signUp(
    String email,
    String password,
    String name,
    String role,
  ) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final credential = await _authService.signUpWithEmail(
        email,
        password,
        name,
      );
      final now = DateTime.now();
      final user = UserModel(
        id: credential.user!.uid,
        name: name,
        email: email,
        role: role,
        createdAt: now,
        updatedAt: now,
      );
      await _authService.createFirestoreUser(user);
    } catch (e) {
      state = AuthState(status: AuthStatus.error, error: e.toString());
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    if (state.user == null) return;
    await _firestoreService.updateUser(state.user!.id, data);
  }

  Future<void> refreshProfile() async {
    final uid = state.user?.id;
    if (uid == null) return;
    try {
      final fresh = await _firestoreService.getUserProfile(uid);
      if (fresh != null && mounted) {
        state = state.copyWith(user: fresh);
      }
    } catch (e) {
      debugPrint('AUTH: refreshProfile error $e');
    }
  }

  UserModel? get currentUser => state.user;
  bool get isProvider => state.user?.isProvider ?? false;
  bool get isNGO => state.user?.isNGO ?? false;
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final firestoreServiceProvider = Provider<FirestoreService>(
  (ref) => FirestoreService(),
);

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(authServiceProvider),
    ref.watch(firestoreServiceProvider),
  );
});

final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authProvider).user;
});

final isProviderProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.isProvider ?? false;
});
