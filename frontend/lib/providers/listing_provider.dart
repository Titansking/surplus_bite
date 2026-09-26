import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/listing_model.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';

class ListingFilter {
  final String category;
  final double? maxDistance;
  final List<String> dietaryTags;

  const ListingFilter({
    this.category = 'All',
    this.maxDistance,
    this.dietaryTags = const [],
  });

  ListingFilter copyWith({
    String? category,
    double? maxDistance,
    List<String>? dietaryTags,
  }) {
    return ListingFilter(
      category: category ?? this.category,
      maxDistance: maxDistance ?? this.maxDistance,
      dietaryTags: dietaryTags ?? this.dietaryTags,
    );
  }
}

class ListingFilterNotifier extends StateNotifier<ListingFilter> {
  ListingFilterNotifier() : super(const ListingFilter());

  void setCategory(String category) {
    state = state.copyWith(category: category);
  }

  void setMaxDistance(double? distance) {
    state = state.copyWith(maxDistance: distance);
  }

  void toggleDietaryTag(String tag) {
    final tags = List<String>.from(state.dietaryTags);
    if (tags.contains(tag)) {
      tags.remove(tag);
    } else {
      tags.add(tag);
    }
    state = state.copyWith(dietaryTags: tags);
  }

  void reset() {
    state = const ListingFilter();
  }
}

final listingFilterProvider =
    StateNotifierProvider<ListingFilterNotifier, ListingFilter>((ref) {
  return ListingFilterNotifier();
});

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchListingsProvider =
    FutureProvider.family<List<ListingModel>, String>((ref, query) async {
  final all = await ref.watch(allListingsProvider.future);
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return all;
  return all
      .where(
        (l) =>
            l.title.toLowerCase().contains(q) ||
            l.description.toLowerCase().contains(q) ||
            l.category.toLowerCase().contains(q) ||
            l.pickupLocation.toLowerCase().contains(q) ||
            l.dietaryTags.any((t) => t.toLowerCase().contains(q)),
      )
      .toList();
});

final allListingsProvider = StreamProvider<List<ListingModel>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.allListings();
});

final categoryListingsProvider =
    StreamProvider.family<List<ListingModel>, String>((ref, category) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.categoryListings(category);
});

final providerListingsProvider =
    StreamProvider.family<List<ListingModel>, String>((ref, providerId) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.providerListings(providerId);
});

final listingDetailProvider =
    FutureProvider.family<ListingModel?, String>((ref, listingId) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getListing(listingId);
});

final favoriteListingsProvider =
    FutureProvider.family<List<ListingModel>, String>((ref, userId) async {
  final favorites = await ref.watch(favoritesProvider(userId).future);
  final all = await ref.watch(allListingsProvider.future);
  final favoriteIds = favorites.toSet();
  return all.where((l) => favoriteIds.contains(l.id)).toList();
});
