import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:surplus_bite/models/review_model.dart';

void main() {
  final now = DateTime(2026, 9, 21, 12, 0, 0);

  ReviewModel buildReview() {
    return ReviewModel(
      id: 'review-1',
      orderId: 'order-1',
      reviewerId: 'buyer-1',
      reviewerName: 'Aisha',
      revieweeId: 'provider-1',
      rating: 5,
      comment: 'Excellent food!',
      createdAt: now,
    );
  }

  group('ReviewModel.fromMap', () {
    test('parses all fields', () {
      final review = ReviewModel.fromMap(
        {
          'orderId': 'order-1',
          'reviewerId': 'buyer-1',
          'reviewerName': 'Aisha',
          'revieweeId': 'provider-1',
          'rating': 5,
          'comment': 'Excellent food!',
          'createdAt': Timestamp.fromDate(now),
        },
        id: 'review-1',
      );

      expect(review.id, 'review-1');
      expect(review.orderId, 'order-1');
      expect(review.reviewerName, 'Aisha');
      expect(review.revieweeId, 'provider-1');
      expect(review.rating, 5);
      expect(review.comment, 'Excellent food!');
      expect(review.createdAt, now);
    });

    test('applies defaults for missing fields', () {
      final review = ReviewModel.fromMap(
        {'createdAt': Timestamp.fromDate(now)},
        id: 'review-1',
      );

      expect(review.rating, 0);
      expect(review.comment, '');
      expect(review.orderId, '');
    });
  });

  group('round trip + equality', () {
    test('fromMap(toFirestore) preserves core values', () {
      final original = buildReview();
      final restored =
          ReviewModel.fromMap(original.toFirestore(), id: original.id);

      expect(restored.id, original.id);
      expect(restored.orderId, original.orderId);
      expect(restored.rating, original.rating);
      expect(restored.comment, original.comment);
      expect(restored.createdAt, original.createdAt);
    });

    test('equality uses props', () {
      expect(buildReview(), buildReview());
      expect(
        ReviewModel(
          id: 'review-2',
          orderId: 'order-1',
          reviewerId: 'buyer-1',
          reviewerName: 'Aisha',
          revieweeId: 'provider-1',
          rating: 5,
          createdAt: now,
        ),
        isNot(buildReview()),
      );
    });
  });
}