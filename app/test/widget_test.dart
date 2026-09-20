import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:surplus_bite/main.dart';

import 'helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'SurplusBiteApp shows splash while the session is being restored',
    (tester) async {
      await tester.pumpWidget(
        providerScope(
          auth: FakeAuthService(
            authStateListener: () => const Stream<User?>.empty(),
          ),
          child: const SurplusBiteApp(),
        ),
      );

      await tester.pump();
      expect(find.byIcon(Icons.eco), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );

  testWidgets(
    'SurplusBiteApp lands on login when no session exists',
    (tester) async {
      await tester.pumpWidget(
        providerScope(
          auth: FakeAuthService(
            authStateListener: () => Stream<User?>.fromIterable(const [null]),
          ),
          child: const SurplusBiteApp(),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('SurplusBite'), findsOneWidget);
    },
  );
}