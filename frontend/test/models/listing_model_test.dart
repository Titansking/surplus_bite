import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:surplus_bite/models/listing_model.dart';

void main() {
  final now = DateTime(2026, 9, 21, 12, 0, 0);
  const baseLocation = GeoPoint(28.6139, 77.2090);

  ListingModel buildListing({
    String status = 'available',
    double originalPrice = 200,
    double discountedPrice = 120,
    int quantity = 5,
    DateTime? pickupEnd,
    DateTime? expiryDate,
  }) {
    return ListingModel(
      id: 'listing-1',
      providerId: 'provider-1',
      providerName: 'Fresh Bites',
      providerPhone: '+919876543210',
      title: 'Surplus Biryani',
      description: 'Fresh biryani, good for dinner.',
      category: 'Meals',
      originalPrice: originalPrice,
      discountedPrice: discountedPrice,
      quantity: quantity,
      unit: 'kg',
      location: baseLocation,
      address: 'MG Road',
      pickupLocation: 'Fresh Bites, MG Road',
      pickupStart: now.subtract(const Duration(hours: 1)),
      pickupEnd: pickupEnd ?? DateTime(2027, 1, 1),
      expiryDate: expiryDate,
      status: status,
      dietaryTags: const ['veg', 'spicy'],
      createdAt: now,
      updatedAt: now,
    );
  }

  group('ListingModel.fromMap', () {
    test('parses all fields', () {
      final listing = ListingModel.fromMap(
        {
          'providerId': 'provider-1',
          'providerName': 'Fresh Bites',
          'providerPhone': '+919876543210',
          'title': 'Surplus Biryani',
          'description': 'Fresh biryani, good for dinner.',
          'category': 'Meals',
          'originalPrice': 200.0,
          'discountedPrice': 120.0,
          'quantity': 5,
          'unit': 'kg',
          'images': ['a.jpg', 'b.jpg'],
          'location': baseLocation,
          'address': 'MG Road',
          'pickupLocation': 'Fresh Bites, MG Road',
          'pickupStart': Timestamp.fromDate(
            now.subtract(const Duration(hours: 1)),
          ),
          'pickupEnd': Timestamp.fromDate(now.add(const Duration(hours: 3))),
          'expiryDate': Timestamp.fromDate(now),
          'status': 'available',
          'dietaryTags': ['veg', 'spicy'],
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        },
        id: 'listing-1',
      );

      expect(listing.id, 'listing-1');
      expect(listing.title, 'Surplus Biryani');
      expect(listing.category, 'Meals');
      expect(listing.originalPrice, 200.0);
      expect(listing.discountedPrice, 120.0);
      expect(listing.quantity, 5);
      expect(listing.location, baseLocation);
      expect(listing.dietaryTags, ['veg', 'spicy']);
      expect(listing.status, 'available');
    });

    test('applies defaults for missing fields', () {
      final listing = ListingModel.fromMap(
        {
          'pickupStart': Timestamp.fromDate(now),
          'pickupEnd': Timestamp.fromDate(now),
        },
        id: 'listing-1',
      );

      expect(listing.title, '');
      expect(listing.category, '');
      expect(listing.unit, 'pieces');
      expect(listing.status, 'available');
      expect(listing.images, isEmpty);
      expect(listing.dietaryTags, isEmpty);
      expect(listing.discountPercent, 0);
    });
  });

  group('round trip', () {
    test('fromMap(toFirestore) preserves core values', () {
      final original = buildListing();
      final restored =
          ListingModel.fromMap(original.toFirestore(), id: original.id);

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.category, original.category);
      expect(restored.originalPrice, original.originalPrice);
      expect(restored.discountedPrice, original.discountedPrice);
      expect(restored.quantity, original.quantity);
      expect(restored.status, original.status);
      expect(restored.dietaryTags, original.dietaryTags);
    });
  });

  group('computed values', () {
    test('discountPercent', () {
      expect(buildListing().discountPercent, 40);
      expect(buildListing(originalPrice: 0).discountPercent, 0);
    });

    test('isAvailable', () {
      expect(buildListing().isAvailable, isTrue);
      expect(buildListing(status: 'reserved').isAvailable, isFalse);
    });

    test('isExpired via expiryDate', () {
      final past = buildListing(
        expiryDate: DateTime(2026, 9, 20),
      );
      expect(past.isExpired, isTrue);
    });

    test('isExpired via pickupEnd', () {
      final past = buildListing(
        pickupEnd: DateTime(2026, 9, 20),
      );
      expect(past.isExpired, isTrue);
    });

    test('not expired while pickup window open', () {
      expect(buildListing().isExpired, isFalse);
    });
  });

  group('distanceFrom', () {
    test('returns ~0 for identical points', () {
      expect(buildListing().distanceFrom(baseLocation), lessThan(0.001));
    });

    test('returns ~111km for 1 degree of latitude', () {
      final oneDegreeNorth = GeoPoint(baseLocation.latitude + 1, baseLocation.longitude);
      final distance = buildListing().distanceFrom(oneDegreeNorth);
      expect(distance, closeTo(111.19, 2.0));
    });
  });

  group('copyWith + equality', () {
    test('copyWith updates only provided fields', () {
      final updated = buildListing().copyWith(
        title: 'New Title',
        quantity: 10,
      );
      expect(updated.title, 'New Title');
      expect(updated.quantity, 10);
      expect(updated.providerId, 'provider-1');
      expect(updated.category, 'Meals');
    });

    test('equality uses props', () {
      expect(buildListing(), buildListing());
      expect(buildListing().copyWith(title: 'Other'), isNot(buildListing()));
    });
  });
}