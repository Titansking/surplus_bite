import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/listing_model.dart';
import '../models/order_model.dart';
import '../models/review_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== USERS ====================

  Stream<UserModel?> userStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map(
          (doc) => doc.exists ? UserModel.fromFirestore(doc) : null,
        );
  }

  Future<UserModel?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    data['updatedAt'] = Timestamp.now();
    await _firestore.collection('users').doc(uid).update(data);
  }

  Future<void> toggleFavorite(String userId, String listingId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    final favorites = List<String>.from(doc.data()?['favorites'] ?? []);
    if (favorites.contains(listingId)) {
      favorites.remove(listingId);
    } else {
      favorites.add(listingId);
    }
    await _firestore.collection('users').doc(userId).update({
      'favorites': favorites,
    });
  }

  Future<List<String>> getUserFavorites(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return List<String>.from(doc.data()?['favorites'] ?? []);
  }

  // ==================== LISTINGS ====================

  Stream<List<ListingModel>> nearbyListings(GeoPoint center, double radiusKm) {
    // Firestore doesn't natively support geo queries, so we fetch
    // and filter. For production, use geohashes.
    return _firestore
        .collection('listings')
        .where('status', isEqualTo: 'available')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ListingModel.fromFirestore(doc))
          .where((listing) => listing.distanceFrom(center) <= radiusKm)
          .toList();
    });
  }

  Stream<List<ListingModel>> allListings() {
    return _firestore
        .collection('listings')
        .where('status', isEqualTo: 'available')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ListingModel.fromFirestore(doc))
            // Client-side expiry so we don't need Cloud Functions
            .where((listing) => !listing.isExpired)
            .toList());
  }

  Stream<List<ListingModel>> providerListings(String providerId) {
    return _firestore
        .collection('listings')
        .where('providerId', isEqualTo: providerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ListingModel.fromFirestore(doc))
            .toList());
  }

  Stream<List<ListingModel>> categoryListings(String category) {
    if (category == 'All') return allListings();
    return _firestore
        .collection('listings')
        .where('status', isEqualTo: 'available')
        .where('category', isEqualTo: category)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ListingModel.fromFirestore(doc))
            .where((listing) => !listing.isExpired)
            .toList());
  }

  Future<DocumentReference> createListing(ListingModel listing) async {
    return await _firestore.collection('listings').add(listing.toFirestore());
  }

  Future<void> updateListing(String id, Map<String, dynamic> data) async {
    data['updatedAt'] = Timestamp.now();
    await _firestore.collection('listings').doc(id).update(data);
  }

  Future<void> deleteListing(String id) async {
    await _firestore.collection('listings').doc(id).delete();
  }

  Future<ListingModel?> getListing(String id) async {
    final doc = await _firestore.collection('listings').doc(id).get();
    if (doc.exists) {
      return ListingModel.fromFirestore(doc);
    }
    return null;
  }

  // ==================== ORDERS ====================

  Stream<List<OrderModel>> buyerOrders(String buyerId) {
    return _firestore
        .collection('orders')
        .where('buyerId', isEqualTo: buyerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OrderModel.fromFirestore(doc))
            .toList());
  }

  Stream<List<OrderModel>> providerOrders(String providerId) {
    return _firestore
        .collection('orders')
        .where('providerId', isEqualTo: providerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OrderModel.fromFirestore(doc))
            .toList());
  }

  Future<DocumentReference> createOrder(OrderModel order) async {
    return await _firestore.collection('orders').add(order.toFirestore());
  }

  Future<void> updateOrder(String id, Map<String, dynamic> data) async {
    data['updatedAt'] = Timestamp.now();
    await _firestore.collection('orders').doc(id).update(data);
  }

  /// Cancels an order and, when the caller is the provider who owns the
  /// listing, returns the reserved stock in the same transaction so the two
  /// writes can never drift apart.
  ///
  /// A buyer cancelling only updates the order: security rules deliberately
  /// forbid a non-owner from increasing a listing's quantity, so the stock is
  /// released by [restoreListingStock] from the provider's side.
  Future<void> cancelOrder(String orderId, String reason) async {
    await _firestore.runTransaction((txn) async {
      final orderRef = _firestore.collection('orders').doc(orderId);
      final orderSnap = await txn.get(orderRef);
      if (!orderSnap.exists) {
        throw StateError('Order no longer exists.');
      }
      final order = OrderModel.fromMap(
        orderSnap.data() as Map<String, dynamic>,
        id: orderSnap.id,
      );
      if (order.isCancelled) return;

      txn.update(orderRef, {
        'status': 'cancelled',
        'cancellationReason': reason,
        'updatedAt': Timestamp.now(),
      });
    });
  }

  /// Returns a cancelled order's reserved units to its listing. Safe to call
  /// more than once: the order records that the stock was released, and a
  /// second call is a no-op.
  Future<void> restoreListingStock(String orderId) async {
    await _firestore.runTransaction((txn) async {
      final orderRef = _firestore.collection('orders').doc(orderId);
      final orderSnap = await txn.get(orderRef);
      if (!orderSnap.exists) return;

      final data = orderSnap.data() as Map<String, dynamic>;
      if (data['status'] != 'cancelled') return;
      if (data['stockRestored'] == true) return;

      final released = (data['quantity'] as num?)?.toInt() ?? 0;
      if (released <= 0) return;

      final listingId = data['listingId'] as String?;
      if (listingId != null && listingId.isNotEmpty) {
        final listingRef = _firestore.collection('listings').doc(listingId);
        final listingSnap = await txn.get(listingRef);
        if (listingSnap.exists) {
          final listing = ListingModel.fromMap(
            listingSnap.data() as Map<String, dynamic>,
            id: listingSnap.id,
          );
          txn.update(listingRef, {
            'quantity': listing.quantity + released,
            // Stock is back on the shelf unless the listing had already been
            // closed out by expiry.
            'status': listing.status == 'expired' ? 'expired' : 'available',
            'updatedAt': Timestamp.now(),
          });
        }
      }

      txn.update(orderRef, {'stockRestored': true});
    });
  }

  /// Advances an order through its lifecycle, invalidating the listing once
  /// the collection is confirmed so the feed stops offering picked-up food.
  Future<void> advanceOrderStatus(String orderId, String status) async {
    await _firestore.runTransaction((txn) async {
      final orderRef = _firestore.collection('orders').doc(orderId);
      final orderSnap = await txn.get(orderRef);
      if (!orderSnap.exists) throw StateError('Order no longer exists.');

      txn.update(orderRef, {
        'status': status,
        'updatedAt': Timestamp.now(),
      });

      // Cancelling hands the reserved units back; completing only closes the
      // listing off once nothing is left. A cancelled order is not marked as
      // released here - [restoreListingStock] does that, and the rules keep the
      // two concerns separate.
      if (status == 'completed') {
        final data = orderSnap.data() as Map<String, dynamic>;
        final listingId = data['listingId'] as String?;
        if (listingId != null && listingId.isNotEmpty) {
          final listingRef = _firestore.collection('listings').doc(listingId);
          final listingSnap = await txn.get(listingRef);
          if (listingSnap.exists) {
            final quantity =
                (listingSnap.data()?['quantity'] as num?)?.toInt() ?? 0;
            if (quantity <= 0) {
              txn.update(listingRef, {
                'status': 'completed',
                'updatedAt': Timestamp.now(),
              });
            }
          }
        }
      }
    });
  }

  /// Reserves [quantity] units of [listingId] for [buyerId] atomically.
  ///
  /// The order is written and the stock is decremented inside a single
  /// transaction, so two buyers racing for the last portion cannot both
  /// succeed. Throws [StateError] when the listing is gone, closed, or does
  /// not have enough stock left.
  Future<String> reserveListing({
    required String listingId,
    required String buyerId,
    required String buyerName,
    required int quantity,
  }) async {
    final listingRef = _firestore.collection('listings').doc(listingId);
    final orderRef = _firestore.collection('orders').doc();

    return _firestore.runTransaction((txn) async {
      final listingSnap = await txn.get(listingRef);
      if (!listingSnap.exists) {
        throw StateError('This listing is no longer available.');
      }

      final listing = ListingModel.fromMap(
        listingSnap.data() as Map<String, dynamic>,
        id: listingSnap.id,
      );

      if (listing.providerId == buyerId) {
        throw StateError('You cannot reserve your own listing.');
      }
      if (listing.status != 'available' || listing.isExpired) {
        throw StateError('This listing is no longer available.');
      }
      if (quantity <= 0) {
        throw StateError('Choose at least one item to reserve.');
      }
      if (quantity > listing.quantity) {
        throw StateError(
          'Only ${listing.quantity} ${listing.unit} left.',
        );
      }

      final remaining = listing.quantity - quantity;

      // The order is created first so the security rules evaluate the stock
      // check against the listing's pre-transaction state.
      txn.set(orderRef, {
        'listingId': listing.id,
        'listingTitle': listing.title,
        'buyerId': buyerId,
        'buyerName': buyerName,
        'providerId': listing.providerId,
        'providerName': listing.providerName,
        'providerPhone': listing.providerPhone,
        'pickupLocation': listing.pickupLocation,
        'quantity': quantity,
        'totalPrice': listing.discountedPrice * quantity,
        'status': 'pending',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      txn.update(listingRef, {
        'quantity': remaining,
        'status': remaining <= 0 ? 'reserved' : 'available',
        'updatedAt': Timestamp.now(),
      });

      return orderRef.id;
    });
  }

  Future<OrderModel?> getOrder(String id) async {
    final doc = await _firestore.collection('orders').doc(id).get();
    if (doc.exists) {
      return OrderModel.fromFirestore(doc);
    }
    return null;
  }

  // ==================== REVIEWS ====================

  Stream<List<ReviewModel>> reviewsForUser(String userId) {
    return _firestore
        .collection('reviews')
        .where('revieweeId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ReviewModel.fromFirestore(doc))
            .toList());
  }

  /// Stores a review and refreshes the reviewee's aggregate rating.
  ///
  /// The review is written to `reviews/{orderId}`. That deterministic id is
  /// what the security rules rely on to guarantee one review per order, so it
  /// must not be replaced with an auto-generated id.
  Future<void> createReview(ReviewModel review) async {
    final orderId = review.orderId;
    if (orderId.isEmpty) {
      throw ArgumentError('A review must reference an order.');
    }

    await _firestore.collection('reviews').doc(orderId).set(
          review.toFirestore(),
        );

    final reviewsSnap = await _firestore
        .collection('reviews')
        .where('revieweeId', isEqualTo: review.revieweeId)
        .get();

    double totalRating = 0;
    for (final doc in reviewsSnap.docs) {
      totalRating += ((doc.data()['rating'] as num?) ?? 0).toDouble();
    }
    final avgRating = reviewsSnap.docs.isNotEmpty
        ? totalRating / reviewsSnap.docs.length
        : 0.0;

    // `ratingOrderId` is the proof the rules check to confirm this writer
    // really did review that user.
    await _firestore.collection('users').doc(review.revieweeId).update({
      'rating': double.parse(avgRating.toStringAsFixed(1)),
      'totalRatings': reviewsSnap.docs.length,
      'ratingOrderId': orderId,
      'updatedAt': Timestamp.now(),
    });
  }

  // ==================== CHAT ====================

  Stream<QuerySnapshot> chatRooms(String userId) {
    return _firestore
        .collection('chat_rooms')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> messages(String chatRoomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  Future<void> sendMessage(
      String chatRoomId, Map<String, dynamic> message) async {
    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .add(message);

    await _firestore.collection('chat_rooms').doc(chatRoomId).update({
      'lastMessage': message['text'] ?? '',
      'lastMessageTime': message['timestamp'],
      'lastMessageSenderId': message['senderId'],
    });
  }

  Future<String> createChatRoom(
      String userId1, String userId2, String userName1, String userName2) async {
    final existing = await _firestore
        .collection('chat_rooms')
        .where('participants', arrayContains: userId1)
        .get();

    for (final doc in existing.docs) {
      final participants = List<String>.from(doc.data()['participants'] ?? []);
      if (participants.contains(userId2)) {
        return doc.id;
      }
    }

    final ref = await _firestore.collection('chat_rooms').add({
      'participants': [userId1, userId2],
      'participantNames': {userId1: userName1, userId2: userName2},
      'lastMessage': '',
      'lastMessageTime': Timestamp.now(),
      'createdAt': Timestamp.now(),
    });
    return ref.id;
  }

  // ==================== ANALYTICS ====================

  Future<Map<String, dynamic>> getProviderStats(String providerId) async {
    final listingsSnap = await _firestore
        .collection('listings')
        .where('providerId', isEqualTo: providerId)
        .get();

    final ordersSnap = await _firestore
        .collection('orders')
        .where('providerId', isEqualTo: providerId)
        .get();

    double totalEarnings = 0;
    int completedOrders = 0;
    double totalFoodSaved = 0;

    for (final doc in ordersSnap.docs) {
      final data = doc.data();
      if (data['status'] == 'completed') {
        totalEarnings += (data['totalPrice'] ?? 0).toDouble();
        completedOrders++;
      }
    }

    for (final doc in listingsSnap.docs) {
      final data = doc.data();
      totalFoodSaved += (data['quantity'] ?? 0).toDouble();
    }

    return {
      'totalListings': listingsSnap.docs.length,
      'totalOrders': ordersSnap.docs.length,
      'completedOrders': completedOrders,
      'totalEarnings': totalEarnings,
      'totalFoodSavedKg': totalFoodSaved,
      'co2Saved': totalFoodSaved * 2.5,
    };
  }
}
