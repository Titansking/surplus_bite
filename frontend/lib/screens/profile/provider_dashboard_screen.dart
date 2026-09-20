import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/listing_provider.dart';
import '../../providers/order_provider.dart';
import '../../utils/formatters.dart';

class ProviderDashboardScreen extends ConsumerWidget {
  const ProviderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final statsAsync = ref.watch(providerStatsProvider(user.id));

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(providerStatsProvider(user.id));
          ref.invalidate(providerListingsProvider(user.id));
          try {
            await ref.read(providerStatsProvider(user.id).future);
            await ref.read(providerListingsProvider(user.id).future);
          } catch (_) {}
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              statsAsync.when(
                data: (stats) => _buildStatsGrid(stats),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Listings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.createListing),
                    child: const Text('+ New Listing'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _RecentListings(providerId: user.id),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic> stats) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Total Listings',
          '${stats['totalListings'] ?? 0}',
          Icons.list_alt,
          AppColors.primary,
        ),
        _buildStatCard(
          'Total Orders',
          '${stats['totalOrders'] ?? 0}',
          Icons.receipt_long,
          AppColors.accent,
        ),
        _buildStatCard(
          'Earnings',
          Formatters.currency((stats['totalEarnings'] ?? 0).toDouble()),
          Icons.attach_money,
          AppColors.success,
        ),
        _buildStatCard(
          'CO₂ Saved',
          '${(stats['co2Saved'] ?? 0).toStringAsFixed(1)} kg',
          Icons.eco,
          AppColors.completed,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentListings extends ConsumerWidget {
  final String providerId;
  const _RecentListings({required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(providerListingsProvider(providerId));
    return listingsAsync.when(
      data: (listings) {
        if (listings.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('No listings yet. Create your first listing!'),
            ),
          );
        }
        return Column(
          children: listings.take(5).map((listing) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: listing.images.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          listing.images.first,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 50,
                            height: 50,
                            color: AppColors.surface,
                            child: const Icon(Icons.fastfood_outlined),
                          ),
                        ),
                      )
                    : Container(
                        width: 50,
                        height: 50,
                        color: AppColors.surface,
                        child: const Icon(Icons.fastfood_outlined),
                      ),
                title: Text(listing.title),
                subtitle: Text(
                  '${Formatters.currency(listing.discountedPrice)} · ${listing.quantity} ${listing.unit}',
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: listing.isAvailable
                        ? AppColors.success.withOpacity(0.1)
                        : AppColors.expired.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    listing.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: listing.isAvailable
                          ? AppColors.success
                          : AppColors.expired,
                    ),
                  ),
                ),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.listingDetail,
                    arguments: listing.id,
                  );
                },
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
    );
  }
}
