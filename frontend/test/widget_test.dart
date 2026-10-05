import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:surplus_bite/main.dart';
import 'package:surplus_bite/models/user_model.dart';

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
      expect(find.byType(Image), findsOneWidget);
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

  testWidgets(
    'SurplusBiteApp moves to home once a session resolves, without a '
    'double-navigation crash',
    (tester) async {
      final auth = StreamController<User?>();
      addTearDown(auth.close);

      final firestore = FakeFirestoreService();
      firestore.profile = UserModel(
        id: 'uid-1',
        name: 'Anna',
        email: 'anna@example.com',
        role: 'consumer',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        providerScope(
          auth: FakeAuthService(authStateListener: () => auth.stream),
          firestore: firestore,
          child: const SurplusBiteApp(),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      auth.add(_StubUser('uid-1'));
      // Fixed pumps rather than pumpAndSettle: the home screen keeps an
      // indefinite progress animation while its feeds load.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // The Navigator is keyed on the destination, so login is torn down
      // exactly once and home is shown without pushing on a defunct context.
      expect(find.text('Sign In'), findsNothing);
      expect(find.text('Home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'signing out returns to login without a double-navigation crash',
    (tester) async {
      final auth = StreamController<User?>();
      addTearDown(auth.close);

      final firestore = FakeFirestoreService();
      firestore.profile = UserModel(
        id: 'uid-1',
        name: 'Anna',
        email: 'anna@example.com',
        role: 'consumer',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        providerScope(
          auth: FakeAuthService(authStateListener: () => auth.stream),
          firestore: firestore,
          child: const SurplusBiteApp(),
        ),
      );
      auth.add(_StubUser('uid-1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Sign In'), findsNothing);

      auth.add(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Sign In'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _StubUser implements User {
  _StubUser(this.uid);

  @override
  final String uid;

  @override
  String? get email => '$uid@example.com';
  @override
  String? get photoURL => null;
  @override
  bool get emailVerified => true;
  @override
  bool get isAnonymous => false;
  @override
  UserMetadata get metadata => _StubUserMetadata();
  @override
  List<UserInfo> get providerData => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubUserMetadata implements UserMetadata {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}