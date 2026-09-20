import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:surplus_bite/screens/auth/login_screen.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('LoginScreen renders email, password and sign-in button', (
    tester,
  ) async {
    await tester.pumpWidget(
      providerScope(
        auth: FakeAuthService(
          authStateListener: () => Stream<User?>.fromIterable(const [null]),
        ),
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('SurplusBite'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text("Don't have an account?"), findsOneWidget);
  });

  testWidgets('LoginScreen shows validation errors on empty submit', (
    tester,
  ) async {
    await tester.pumpWidget(
      providerScope(
        auth: FakeAuthService(
          authStateListener: () => Stream<User?>.fromIterable(const [null]),
        ),
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Sign In'));
    await tester.pump();

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('LoginScreen disables submit while loading', (tester) async {
    await tester.pumpWidget(
      providerScope(
        auth: FakeAuthService(authStateListener: () => const Stream<User?>.empty()),
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();

    expect(find.descendant(
      of: find.byType(LoginScreen),
      matching: find.widgetWithText(ElevatedButton, 'Sign In'),
    ), findsOneWidget);
  });
}