import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:surplus_bite/models/user_model.dart';

void main() {
  final now = DateTime(2026, 9, 21, 12, 0, 0);

  UserModel buildUser() => UserModel(
        id: 'user-1',
        name: 'Priya',
        email: 'priya@gmail.com',
        phone: '+919876543210',
        role: 'provider',
        businessName: 'Fresh Bites',
        rating: 4.5,
        totalRatings: 12,
        favorites: const ['listing-1', 'listing-2'],
        createdAt: now,
        updatedAt: now,
      );

  group('UserModel.fromMap', () {
    test('parses all fields from a Firestore-style map', () {
      final user = UserModel.fromMap(
        {
          'name': 'Priya',
          'email': 'priya@gmail.com',
          'phone': '+919876543210',
          'role': 'provider',
          'businessName': 'Fresh Bites',
          'rating': 4.5,
          'totalRatings': 12,
          'favorites': ['listing-1', 'listing-2'],
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        },
        id: 'user-1',
      );

      expect(user.id, 'user-1');
      expect(user.name, 'Priya');
      expect(user.email, 'priya@gmail.com');
      expect(user.phone, '+919876543210');
      expect(user.role, 'provider');
      expect(user.businessName, 'Fresh Bites');
      expect(user.rating, 4.5);
      expect(user.totalRatings, 12);
      expect(user.favorites, ['listing-1', 'listing-2']);
      expect(user.createdAt, now);
    });

    test('applies defaults for missing fields', () {
      final user = UserModel.fromMap(
        {'createdAt': Timestamp.fromDate(now), 'updatedAt': Timestamp.fromDate(now)},
        id: 'user-1',
      );

      expect(user.name, '');
      expect(user.email, '');
      expect(user.phone, '');
      expect(user.role, 'consumer');
      expect(user.rating, 0.0);
      expect(user.totalRatings, 0);
      expect(user.favorites, isEmpty);
    });
  });

  group('UserModel.toFirestore', () {
    test('stores timestamps and core fields', () {
      final data = buildUser().toFirestore();

      expect(data['name'], 'Priya');
      expect(data['email'], 'priya@gmail.com');
      expect(data['role'], 'provider');
      expect(data['rating'], 4.5);
      expect(data['favorites'], ['listing-1', 'listing-2']);
      expect(data['createdAt'], isA<Timestamp>());
      expect(data['updatedAt'], isA<Timestamp>());
    });
  });

  group('round trip', () {
    test('fromMap(toFirestore) preserves values', () {
      final original = buildUser();
      final restored = UserModel.fromMap(original.toFirestore(), id: original.id);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.email, original.email);
      expect(restored.role, original.role);
      expect(restored.rating, original.rating);
      expect(restored.totalRatings, original.totalRatings);
      expect(restored.favorites, original.favorites);
      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt, original.updatedAt);
    });
  });

  group('copyWith', () {
    test('updates only provided fields', () {
      final updated = buildUser().copyWith(
        name: 'Priya Nair',
        role: 'consumer',
        location: const GeoPoint(28.6139, 77.2090),
      );

      expect(updated.name, 'Priya Nair');
      expect(updated.role, 'consumer');
      expect(updated.location, const GeoPoint(28.6139, 77.2090));
      expect(updated.email, 'priya@gmail.com');
      expect(updated.rating, 4.5);
    });
  });

  group('role helpers', () {
    test('isProvider', () {
      expect(buildUser().isProvider, isTrue);
      expect(
        buildUser().copyWith(role: 'consumer').isProvider,
        isFalse,
      );
    });

    test('isNGO', () {
      expect(buildUser().copyWith(role: 'ngo').isNGO, isTrue);
      expect(buildUser().isNGO, isFalse);
    });

    test('isConsumer', () {
      expect(buildUser().copyWith(role: 'consumer').isConsumer, isTrue);
      expect(buildUser().isConsumer, isFalse);
    });
  });

  group('equality', () {
    test('uses props for == and hashCode', () {
      expect(buildUser(), buildUser());
      expect(buildUser().hashCode, buildUser().hashCode);
      expect(buildUser().copyWith(name: 'Other'), isNot(buildUser()));
    });
  });
}