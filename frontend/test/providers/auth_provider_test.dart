import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:surplus_bite/models/user_model.dart';
import 'package:surplus_bite/providers/auth_provider.dart';

import '../helpers/fakes.dart';

void main() {
  Future<void> waitForStatus(
    ProviderContainer container,
    AuthStatus expected,
  ) async {
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (container.read(authProvider).status != expected &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  group('AuthNotifier', () {
    test('resolves to unauthenticated when auth stream emits null', () async {
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(
            FakeAuthService(
              authStateListener: () => Stream<User?>.fromIterable(const [null]),
            ),
          ),
          firestoreServiceProvider.overrideWithValue(FakeFirestoreService()),
        ],
      );
      addTearDown(container.dispose);

      await waitForStatus(container, AuthStatus.unauthenticated);

      expect(container.read(authProvider).status, AuthStatus.unauthenticated);
    });

    test('holds on the initial splash state before the stream emits', () {
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(
            FakeAuthService(
              authStateListener: () => const Stream<User?>.empty(),
            ),
          ),
          firestoreServiceProvider.overrideWithValue(FakeFirestoreService()),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(authProvider).status, AuthStatus.initial);
    });

    test('signIn transitions to error when credentials are invalid', () async {
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(
            FakeAuthService(
              authStateListener: () => Stream<User?>.fromIterable(const [null]),
              onSignIn: (email, password) {
                throw Exception('Invalid credentials');
              },
            ),
          ),
          firestoreServiceProvider.overrideWithValue(FakeFirestoreService()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).signIn('a@b.c', 'wrong');

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.error);
      expect(state.error, contains('Invalid credentials'));
    });

    test('signUp transitions to error when email is taken', () async {
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(
            FakeAuthService(
              authStateListener: () => Stream<User?>.fromIterable(const [null]),
              onSignUp: (email, password, name) {
                throw Exception('Email already in use');
              },
            ),
          ),
          firestoreServiceProvider.overrideWithValue(FakeFirestoreService()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authProvider.notifier)
          .signUp('a@b.c', 'secret1', 'Anna', 'consumer');

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.error);
      expect(state.error, contains('Email already in use'));
    });

    test('signUp surfaces an error when Firebase returns no user', () async {
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(
            FakeAuthService(
              authStateListener: () => Stream<User?>.fromIterable(const [null]),
              signUpResult: (_, _) => _FakeUserCredential(null),
            ),
          ),
          firestoreServiceProvider.overrideWithValue(FakeFirestoreService()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authProvider.notifier)
          .signUp('a@b.c', 'secret1', 'Anna', 'consumer');

      final state = container.read(authProvider);
      // A null credential must become a handled error, not a null-check crash.
      expect(state.status, AuthStatus.error);
      expect(state.error, isNotNull);
    });

    test('signUp rolls the auth account back when the profile write fails',
        () async {
      final rolledBack = <String>[];

      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(
            FakeAuthService(
              authStateListener: () => Stream<User?>.fromIterable(const [null]),
              signUpResult: (_, _) => _FakeUserCredential(_FakeUser('uid-42')),
              onCreateFirestoreUser: (_) =>
                  throw Exception('PERMISSION_DENIED'),
              onRollback: rolledBack.add,
            ),
          ),
          firestoreServiceProvider.overrideWithValue(FakeFirestoreService()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authProvider.notifier)
          .signUp('a@b.c', 'secret1', 'Anna', 'provider');

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.error);
      // Without the rollback the user would be stuck signed in with no profile.
      expect(rolledBack, ['uid-42']);
    });

    test('signUp succeeds when the profile is created', () async {
      final created = <UserModel>[];

      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(
            FakeAuthService(
              authStateListener: () => Stream<User?>.fromIterable(const [null]),
              signUpResult: (_, _) => _FakeUserCredential(_FakeUser('uid-7')),
              onCreateFirestoreUser: created.add,
            ),
          ),
          firestoreServiceProvider.overrideWithValue(FakeFirestoreService()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authProvider.notifier)
          .signUp('a@b.c', 'secret1', 'Anna', 'provider');

      expect(created, hasLength(1));
      expect(created.single.role, 'provider');
      expect(created.single.id, 'uid-7');
      // No spurious error state.
      expect(container.read(authProvider).status, isNot(AuthStatus.error));
    });

    test('a profile lookup failure does not eject a valid session', () async {
      final firestore = FakeFirestoreService();
      firestore.profileError = Exception('offline');

      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(
            FakeAuthService(
              authStateListener: () => Stream<User?>.fromIterable([
                _FakeUser('uid-9', displayName: 'Anna'),
              ]),
            ),
          ),
          firestoreServiceProvider.overrideWithValue(firestore),
        ],
      );
      addTearDown(container.dispose);

      await waitForStatus(container, AuthStatus.authenticated);

      final state = container.read(authProvider);
      // A flaky read must not sign the user out of the UI.
      expect(state.status, AuthStatus.authenticated);
      expect(state.error, contains('offline'));
    });

    test('a stale profile read cannot overwrite the current session', () async {
      final gate = Completer<void>();
      var releaseGate = false;

      final firestore = FakeFirestoreService(
        onGetProfile: (uid) async {
          if (uid == 'uid-slow' && !releaseGate) {
            await gate.future;
            return UserModel(
              id: uid,
              name: 'Stale',
              email: '$uid@x.com',
              role: 'consumer',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
          }
          return UserModel(
            id: uid,
            name: 'Fresh',
            email: '$uid@x.com',
            role: 'consumer',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        },
      );

      final controller = StreamController<User?>();
      addTearDown(controller.close);

      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(
            FakeAuthService(authStateListener: () => controller.stream),
          ),
          firestoreServiceProvider.overrideWithValue(firestore),
        ],
      );
      addTearDown(container.dispose);

      controller.add(_FakeUser('uid-slow'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      controller.add(_FakeUser('uid-fast'));

      await waitForStatus(container, AuthStatus.authenticated);
      expect(container.read(authProvider).user?.name, 'Fresh');

      // Now let the slow read finish; it must be discarded.
      releaseGate = true;
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(container.read(authProvider).user?.name, 'Fresh');
    });

    test('dispose cancels the auth subscription', () async {
      final controller = StreamController<User?>();
      addTearDown(controller.close);

      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(
            FakeAuthService(authStateListener: () => controller.stream),
          ),
          firestoreServiceProvider.overrideWithValue(FakeFirestoreService()),
        ],
      );

      container.read(authProvider); // instantiate the notifier
      container.dispose();

      // A leaked subscription would keep the notifier alive and write to a
      // disposed StateNotifier.
      expect(controller.hasListener, isFalse);
    });
  });
}

class _FakeUser implements User {
  _FakeUser(this.uid, {this.displayName});

  @override
  final String uid;
  @override
  final String? displayName;

  @override
  String? get email => '$uid@example.com';
  @override
  String? get photoURL => null;
  @override
  bool get emailVerified => true;
  @override
  bool get isAnonymous => false;
  @override
  UserMetadata get metadata => _FakeUserMetadata();
  @override
  List<UserInfo> get providerData => const [];
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeUserMetadata implements UserMetadata {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeUserCredential implements UserCredential {
  _FakeUserCredential(this.user);

  @override
  final User? user;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}