import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/local_account.dart';
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
  final AccountsNotifier _accounts;

  StreamSubscription<User?>? _authSubscription;
  int _authEpoch = 0;

  AuthNotifier(this._authService, this._firestoreService, this._accounts)
    : super(const AuthState()) {
    _init();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _authSubscription = null;
    super.dispose();
  }

  void _init() {
    _authSubscription = _authService.authStateChanges.listen((user) async {
      // Every emission supersedes any in-flight profile lookup, so a slow read
      // from a previous account can never overwrite the current one.
      final epoch = ++_authEpoch;
      try {
        if (user != null) {
          debugPrint('AUTH: user != null, fetching profile for ${user.uid}');
          var userModel = await _firestoreService
              .getUserProfile(user.uid)
              .timeout(const Duration(seconds: 10));

          if (!mounted || epoch != _authEpoch) return;

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
            if (!mounted || epoch != _authEpoch) return;
          }

          _accounts.upsert(
            LocalAccount(
              uid: user.uid,
              email: user.email ?? '',
              name: user.displayName ?? userModel.name,
              photoUrl: user.photoURL,
              provider: user.providerData.isNotEmpty
                  ? user.providerData.first.providerId
                  : 'password',
            ),
          );

          debugPrint('AUTH: profile fetched: true');
          state = AuthState(status: AuthStatus.authenticated, user: userModel);
        } else {
          debugPrint('AUTH: user == null');
          state = const AuthState(status: AuthStatus.unauthenticated);
        }
      } catch (e) {
        if (!mounted || epoch != _authEpoch) return;
        debugPrint('AUTH: error $e');
        // A profile lookup failure must not eject an otherwise valid session:
        // keep the user signed in and surface the error alongside the user.
        state = user != null
            ? AuthState(
                status: AuthStatus.authenticated,
                user: state.user,
                error: e.toString(),
              )
            : AuthState(status: AuthStatus.error, error: e.toString());
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

  Future<void> switchGoogleAccount() async {
    final previous = state;
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _authService.signInWithGoogle();
    } catch (e) {
      final isCancel =
          e is GoogleSignInException &&
          e.code == GoogleSignInExceptionCode.canceled;
      state = isCancel
          ? previous.copyWith(status: AuthStatus.authenticated)
          : AuthState(status: AuthStatus.error, error: e.toString());
    }
  }

  Future<void> switchToEmailAccount(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _authService.signInWithEmail(email, password);
    } catch (e) {
      state = AuthState(status: AuthStatus.error, error: e.toString());
    }
  }

  List<LocalAccount> get accounts => _accounts.state;

  void removeLocalAccount(String uid) {
    _accounts.remove(uid);
  }

  Future<bool> resetPassword(String email) async {
    try {
      await _authService.resetPassword(email);
      return true;
    } catch (e) {
      state = AuthState(status: AuthStatus.error, error: e.toString());
      return false;
    }
  }

  Future<void> signUp(
    String email,
    String password,
    String name,
    String role,
  ) async {
    state = state.copyWith(status: AuthStatus.loading);
    User? created;
    try {
      final credential = await _authService.signUpWithEmail(
        email,
        password,
        name,
      );
      // `user` is null when Firebase applies email-enumeration protection;
      // a hard unwrap here would crash the sign-up flow.
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw StateError(
          'Sign-up did not return a user. Please try signing in instead.',
        );
      }
      created = firebaseUser;

      final now = DateTime.now();
      final user = UserModel(
        id: firebaseUser.uid,
        name: name,
        email: email,
        role: role,
        createdAt: now,
        updatedAt: now,
      );
      await _authService.createFirestoreUser(user);
    } catch (e) {
      // Roll the auth account back so a half-created user cannot get stuck in
      // a signed-in state with no Firestore profile.
      if (created != null) {
        try {
          await _authService.rollbackUser(created.uid);
        } catch (rollbackError) {
          debugPrint('AUTH: sign-up rollback failed: $rollbackError');
        }
      }
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

/// Holds the sign-up details between the register form and the role picker.
/// This is deliberately a provider rather than a route argument: route
/// arguments are retained by the Navigator for the route's lifetime, which
/// would keep the plaintext password alive in memory (and in any route
/// logging) far longer than needed.
final pendingRegistrationProvider =
    StateProvider<PendingRegistration?>((ref) => null);

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final firestoreServiceProvider = Provider<FirestoreService>(
  (ref) => FirestoreService(),
);

class LocalAccountsStore {
  LocalAccountsStore([this._sp]);

  final SharedPreferences? _sp;
  String? _cache;
  static const _key = 'local_accounts_v1';

  String? read() => _sp?.getString(_key) ?? _cache;

  Future<void> write(String value) async {
    _cache = value;
    await _sp?.setString(_key, value);
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

final localAccountsStoreProvider = Provider<LocalAccountsStore>((ref) {
  return LocalAccountsStore(ref.watch(sharedPreferencesProvider));
});

class AccountsNotifier extends StateNotifier<List<LocalAccount>> {
  AccountsNotifier(this._store) : super(const []) {
    _load();
  }

  final LocalAccountsStore _store;

  Future<void> _load() async {
    final raw = _store.read();
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      state = decoded
          .map((e) => LocalAccount.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Corrupted registry: fall back to an empty list.
    }
  }

  void upsert(LocalAccount account) {
    state = [account, ...state.where((a) => a.uid != account.uid)];
    _persist();
  }

  void remove(String uid) {
    state = state.where((a) => a.uid != uid).toList();
    _persist();
  }

  void _persist() {
    _store.write(jsonEncode(state.map((e) => e.toJson()).toList()));
  }
}

final accountsProvider =
    StateNotifierProvider<AccountsNotifier, List<LocalAccount>>((ref) {
  return AccountsNotifier(ref.watch(localAccountsStoreProvider));
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.read(authServiceProvider),
    ref.read(firestoreServiceProvider),
    ref.read(accountsProvider.notifier),
  );
});

final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authProvider).user;
});

final isProviderProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.isProvider ?? false;
});
