import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
  });
}