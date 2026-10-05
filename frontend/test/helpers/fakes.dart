import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:surplus_bite/models/listing_model.dart';
import 'package:surplus_bite/models/order_model.dart';
import 'package:surplus_bite/models/review_model.dart';
import 'package:surplus_bite/models/user_model.dart';
import 'package:surplus_bite/providers/auth_provider.dart';
import 'package:surplus_bite/services/auth_service.dart';
import 'package:surplus_bite/services/firestore_service.dart';

class FakeAuthService implements AuthService {
  FakeAuthService({
    this.authStateListener,
    this.onSignIn,
    this.onSignUp,
    this.signUpResult,
    this.onCreateFirestoreUser,
    this.onRollback,
  });

  final Stream<User?> Function()? authStateListener;
  final void Function(String email, String password)? onSignIn;
  final void Function(String email, String password, String name)? onSignUp;

  /// Credential returned by [signUpWithEmail]. Defaults to a throwing
  /// unimplemented so a test that does not care must opt in explicitly.
  final UserCredential? Function(String email, String password)? signUpResult;
  final void Function(UserModel user)? onCreateFirestoreUser;
  final void Function(String uid)? onRollback;

  @override
  User? get currentUser => null;

  @override
  String? get currentUserId => null;

  @override
  Stream<User?> get authStateChanges =>
      authStateListener?.call() ?? const Stream.empty();

  @override
  Future<UserCredential> signInWithEmail(String email, String password) async {
    onSignIn?.call(email, password);
    throw UnimplementedError('signInWithEmail is not exercised in this test');
  }

  @override
  Future<UserCredential?> signInWithGoogle() async {
    throw UnimplementedError('signInWithGoogle is not exercised in this test');
  }

  @override
  Future<UserCredential> signUpWithEmail(
    String email,
    String password,
    String name,
  ) async {
    onSignUp?.call(email, password, name);
    final result = signUpResult?.call(email, password);
    if (result != null) return result;
    throw UnimplementedError('signUpWithEmail is not exercised in this test');
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<void> resetPassword(String email) async {}

  @override
  Future<void> createFirestoreUser(UserModel user) async {
    onCreateFirestoreUser?.call(user);
  }

  @override
  Future<void> rollbackUser(String uid) async {
    onRollback?.call(uid);
  }

  @override
  Future<UserModel?> getFirestoreUser(String uid) async => null;

  @override
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {}

  @override
  Future<void> deleteUser() async {}
}

class FakeFirestoreService implements FirestoreService {
  FakeFirestoreService({this.onGetProfile});

  UserModel? profile;

  /// Thrown by [getUserProfile] when set, to simulate an unreachable backend.
  Object? profileError;

  /// Overrides the profile lookup entirely (used for ordering tests).
  final Future<UserModel?> Function(String uid)? onGetProfile;

  @override
  Future<UserModel?> getUserProfile(String uid) async {
    final error = profileError;
    if (error != null) throw error;
    final handler = onGetProfile;
    if (handler != null) return handler(uid);
    return profile;
  }

  @override
  Stream<UserModel?> userStream(String uid) async* {
    yield profile;
  }

  @override
  Future<void> cancelOrder(String orderId, String reason) async {}

  @override
  Future<void> restoreListingStock(String orderId) async {}

  @override
  Future<void> advanceOrderStatus(String orderId, String status) async {}

  @override
  Future<String> reserveListing({
    required String listingId,
    required String buyerId,
    required String buyerName,
    required int quantity,
  }) async =>
      'order-id';

  @override
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {}

  @override
  Future<void> toggleFavorite(String userId, String listingId) async {}

  @override
  Future<List<String>> getUserFavorites(String userId) async => [];

  @override
  Stream<List<ListingModel>> nearbyListings(GeoPoint center, double radiusKm) =>
      const Stream.empty();

  @override
  Stream<List<ListingModel>> allListings() => const Stream.empty();

  @override
  Stream<List<ListingModel>> providerListings(String providerId) =>
      const Stream.empty();

  @override
  Stream<List<ListingModel>> categoryListings(String category) =>
      const Stream.empty();

  @override
  Future<DocumentReference> createListing(ListingModel listing) async {
    throw UnimplementedError();
  }

  @override
  Future<void> updateListing(String id, Map<String, dynamic> data) async {}

  @override
  Future<void> deleteListing(String id) async {}

  @override
  Future<ListingModel?> getListing(String id) async => null;

  @override
  Stream<List<OrderModel>> buyerOrders(String buyerId) => const Stream.empty();

  @override
  Stream<List<OrderModel>> providerOrders(String providerId) =>
      const Stream.empty();

  @override
  Future<DocumentReference> createOrder(OrderModel order) async {
    throw UnimplementedError();
  }

  @override
  Future<void> updateOrder(String id, Map<String, dynamic> data) async {}

  @override
  Future<OrderModel?> getOrder(String id) async => null;

  @override
  Stream<List<ReviewModel>> reviewsForUser(String userId) =>
      const Stream.empty();

  @override
  Future<void> createReview(ReviewModel review) async {}

  @override
  Stream<QuerySnapshot> chatRooms(String userId) => const Stream.empty();

  @override
  Stream<QuerySnapshot> messages(String chatRoomId) => const Stream.empty();

  @override
  Future<void> sendMessage(
      String chatRoomId, Map<String, dynamic> message) async {}

  @override
  Future<String> createChatRoom(
    String userId1,
    String userId2,
    String userName1,
    String userName2,
  ) async =>
      'room-id';

  @override
  Future<Map<String, dynamic>> getProviderStats(String providerId) async => {};
}

ProviderScope providerScope({
  FakeAuthService? auth,
  FakeFirestoreService? firestore,
  required Widget child,
}) {
  return ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(auth ?? FakeAuthService()),
      firestoreServiceProvider
          .overrideWithValue(firestore ?? FakeFirestoreService()),
    ],
    child: child,
  );
}