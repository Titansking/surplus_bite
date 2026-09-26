import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/listing_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/common/listing_card.dart';
import '../../widgets/common/loading_shimmer.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final listings = ref.watch(favoriteListingsProvider(user.id));
    final favoriteIds = ref.watch(favoritesNotifierProvider(user.id));

    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: listings.when(
        data: (list) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(favoriteListingsProvider(user.id));
              try {
                await ref.read(favoriteListingsProvider(user.id).future);
              } catch (_) {}
            },
            child: list.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      Icon(Icons.favorite_outline,
                          size: 64, color: AppColors.textHint),
                      SizedBox(height: 16),
                      Text(
                        'No favorites yet',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tap the heart on a listing to save it here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textHint),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: 8),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final listing = list[index];
                      return ListingCard(
                        listing: listing,
                        isFavorite: favoriteIds.contains(listing.id),
                        onFavoriteToggle: () => ref
                            .read(favoritesNotifierProvider(user.id).notifier)
                            .toggleFavorite(listing.id),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.listingDetail,
                            arguments: listing.id,
                          );
                        },
                      );
                    },
                  ),
          );
        },
        loading: () => const LoadingShimmer(),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}