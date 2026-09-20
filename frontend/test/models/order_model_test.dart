import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:surplus_bite/models/order_model.dart';

void main() {
  final now = DateTime(2026, 9, 21, 12, 0, 0);

  OrderModel buildOrder({String status = 'pending'}) {
    return OrderModel(
      id: 'order-1',
      listingId: 'listing-1',
      listingTitle: 'Surplus Biryani',
      buyerId: 'buyer-1',
      buyerName: 'Aisha',
      providerId: 'provider-1',
      providerName: 'Fresh Bites',
      quantity: 2,
      totalPrice: 240,
      status: status,
      pickupTime: now.add(const Duration(hours: 2)),
      createdAt: now,
      updatedAt: now,
    );
  }

  group('OrderModel.fromMap', () {
    test('parses all fields', () {
      final order = OrderModel.fromMap(
        {
          'listingId': 'listing-1',
          'listingTitle': 'Surplus Biryani',
          'buyerId': 'buyer-1',
          'buyerName': 'Aisha',
          'providerId': 'provider-1',
          'providerName': 'Fresh Bites',
          'quantity': 2,
          'totalPrice': 240.0,
          'status': 'confirmed',
          'pickupTime': Timestamp.fromDate(now.add(const Duration(hours: 2))),
          'cancellationReason': 'Change of plans',
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        },
        id: 'order-1',
      );

      expect(order.id, 'order-1');
      expect(order.listingTitle, 'Surplus Biryani');
      expect(order.buyerName, 'Aisha');
      expect(order.quantity, 2);
      expect(order.totalPrice, 240.0);
      expect(order.status, 'confirmed');
      expect(order.cancellationReason, 'Change of plans');
      expect(order.pickupTime, now.add(const Duration(hours: 2)));
    });

    test('applies defaults for missing fields', () {
      final order = OrderModel.fromMap(
        {
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        },
        id: 'order-1',
      );

      expect(order.status, 'pending');
      expect(order.quantity, 0);
      expect(order.totalPrice, 0.0);
      expect(order.pickupTime, isNull);
    });
  });

  group('round trip', () {
    test('fromMap(toFirestore) preserves core values', () {
      final original = buildOrder(status: 'completed');
      final restored = OrderModel.fromMap(original.toFirestore(), id: original.id);

      expect(restored.id, original.id);
      expect(restored.listingId, original.listingId);
      expect(restored.buyerId, original.buyerId);
      expect(restored.quantity, original.quantity);
      expect(restored.totalPrice, original.totalPrice);
      expect(restored.status, original.status);
      expect(restored.pickupTime, original.pickupTime);
    });
  });

  group('status helpers', () {
    test('isPending', () => expect(buildOrder().isPending, isTrue));

    test('isConfirmed', () {
      expect(buildOrder(status: 'confirmed').isConfirmed, isTrue);
    });

    test('isPickedUp', () {
      expect(buildOrder(status: 'picked_up').isPickedUp, isTrue);
    });

    test('isCompleted', () {
      expect(buildOrder(status: 'completed').isCompleted, isTrue);
    });

    test('isCancelled', () {
      expect(buildOrder(status: 'cancelled').isCancelled, isTrue);
    });
  });

  group('copyWith + equality', () {
    test('copyWith updates only provided fields', () {
      final updated = buildOrder().copyWith(
        status: 'confirmed',
        quantity: 3,
      );

      expect(updated.status, 'confirmed');
      expect(updated.quantity, 3);
      expect(updated.listingId, 'listing-1');
      expect(updated.totalPrice, 240);
    });

    test('equality uses props', () {
      expect(buildOrder(), buildOrder());
      expect(buildOrder(status: 'cancelled'), isNot(buildOrder()));
    });
  });
}