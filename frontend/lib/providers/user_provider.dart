import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../providers/auth_provider.dart';

final userProvider =
    StreamProvider.family<UserModel?, String>((ref, uid) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.userStream(uid);
});

final favoritesProvider =
    FutureProvider.family<List<String>, String>((ref, userId) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getUserFavorites(userId);
});

final favoritesNotifierProvider =
    StateNotifierProvider.family<FavoriteNotifier, Set<String>, String>((
  ref,
  userId,
) {
  return FavoriteNotifier(ref.watch(firestoreServiceProvider), userId);
});

class FavoriteNotifier extends StateNotifier<Set<String>> {
  final FirestoreService _firestoreService;
  final String _userId;

  FavoriteNotifier(this._firestoreService, this._userId) : super({}) {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favorites = await _firestoreService.getUserFavorites(_userId);
    state = favorites.toSet();
  }

  Future<void> toggleFavorite(String listingId) async {
    await _firestoreService.toggleFavorite(_userId, listingId);
    if (state.contains(listingId)) {
      state = {...state}..remove(listingId);
    } else {
      state = {...state, listingId};
    }
  }

  bool isFavorite(String listingId) => state.contains(listingId);
}
