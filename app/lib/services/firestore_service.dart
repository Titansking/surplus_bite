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

  Future<void> createReview(ReviewModel review) async {
    await _firestore.collection('reviews').add(review.toFirestore());

    // Update provider's average rating
    final reviewsSnap = await _firestore
        .collection('reviews')
        .where('revieweeId', isEqualTo: review.revieweeId)
        .get();

    double totalRating = 0;
    for (final doc in reviewsSnap.docs) {
      totalRating += (doc.data()['rating'] ?? 0).toDouble();
    }
    final avgRating = reviewsSnap.docs.isNotEmpty
        ? totalRating / reviewsSnap.docs.length
        : 0.0;

    await _firestore.collection('users').doc(review.revieweeId).update({
      'rating': double.parse(avgRating.toStringAsFixed(1)),
      'totalRatings': reviewsSnap.docs.length,
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
