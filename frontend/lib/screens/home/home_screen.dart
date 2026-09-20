import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/listing_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/common/listing_card.dart';
import '../../widgets/common/loading_shimmer.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  bool _showMapView = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _HomeTab(
            showMapView: _showMapView,
            onToggleView: () => setState(() => _showMapView = !_showMapView),
          ),
          _OrdersTab(),
          _ProfileTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outlined),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      floatingActionButton: user?.isProvider == true
          ? FloatingActionButton(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.createListing),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}

class _HomeTab extends ConsumerStatefulWidget {
  final bool showMapView;
  final VoidCallback onToggleView;

  const _HomeTab({required this.showMapView, required this.onToggleView});

  @override
  ConsumerState<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<_HomeTab> {
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.eco, color: Colors.white, size: 28),
            const SizedBox(width: 8),
            Text(
              'SurplusBite',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              // TODO: Implement search
            },
            icon: const Icon(Icons.search),
          ),
          IconButton(
            onPressed: widget.onToggleView,
            icon: Icon(widget.showMapView ? Icons.list : Icons.map_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: AppColors.primary,
            child: SizedBox(
              height: 40,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: AppConstants.categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = AppConstants.categories[index];
                  final isSelected = _selectedCategory == cat;
                  return FilterChip(
                    label: Text(
                      cat,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => _selectedCategory = cat);
                      ref.read(listingFilterProvider.notifier).setCategory(cat);
                    },
                    backgroundColor: Colors.white,
                    selectedColor: AppColors.primaryDark,
                    checkmarkColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: widget.showMapView
                ? _MapView(category: _selectedCategory)
                : _ListView(category: _selectedCategory),
          ),
        ],
      ),
    );
  }
}

class _ListView extends ConsumerWidget {
  final String category;

  const _ListView({required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(
      category == 'All'
          ? allListingsProvider
          : categoryListingsProvider(category),
    );

    return listingsAsync.when(
      data: (listings) {
        return RefreshIndicator(
          onRefresh: () async {
            final provider = category == 'All'
                ? allListingsProvider
                : categoryListingsProvider(category);
            ref.invalidate(provider);
            try {
              await ref.read(provider.future);
            } catch (_) {}
          },
          child: listings.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 80),
                    EmptyStateWidget(
                      icon: Icons.fastfood_outlined,
                      title: 'No Listings Found',
                      subtitle:
                          'There are no food listings available in your area yet.',
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: listings.length,
                  itemBuilder: (context, index) {
                    final listing = listings[index];
                    return ListingCard(
                      listing: listing,
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
    );
  }
}

class _MapView extends ConsumerWidget {
  final String category;

  const _MapView({required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, size: 64, color: AppColors.textHint),
          SizedBox(height: 16),
          Text(
            'Map View',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            'Configure Google Maps API key to enable',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _OrdersTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    return DefaultTabController(
      length: user.isProvider ? 2 : 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Orders'),
          bottom: TabBar(
            tabs: [
              if (user.isProvider) const Tab(text: 'Incoming'),
              Tab(text: user.isProvider ? 'My Listings' : 'My Orders'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            if (user.isProvider) _ProviderOrdersList(providerId: user.id),
            _BuyerOrdersList(buyerId: user.id),
          ],
        ),
      ),
    );
  }
}

class _ProviderOrdersList extends ConsumerWidget {
  final String providerId;
  const _ProviderOrdersList({required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(providerOrdersProvider(providerId));
    return ordersAsync.when(
      data: (orders) {
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(providerOrdersProvider(providerId));
            try {
              await ref.read(providerOrdersProvider(providerId).future);
            } catch (_) {}
          },
          child: orders.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 80),
                    EmptyStateWidget(
                      icon: Icons.receipt_long_outlined,
                      title: 'No Incoming Orders',
                      subtitle: 'Orders from consumers will appear here.',
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(8),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(order.listingTitle),
                        subtitle: Text('By ${order.buyerName}'),
                        trailing: Text(
                          '\$${order.totalPrice.toStringAsFixed(2)}',
                        ),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.orderDetail,
                            arguments: order.id,
                          );
                        },
                      ),
                    );
                  },
                ),
        );
      },
      loading: () => const LoadingShimmer(height: 80),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _BuyerOrdersList extends ConsumerWidget {
  final String buyerId;
  const _BuyerOrdersList({required this.buyerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(buyerOrdersProvider(buyerId));
    return ordersAsync.when(
      data: (orders) {
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(buyerOrdersProvider(buyerId));
            try {
              await ref.read(buyerOrdersProvider(buyerId).future);
            } catch (_) {}
          },
          child: orders.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 80),
                    EmptyStateWidget(
                      icon: Icons.shopping_bag_outlined,
                      title: 'No Orders Yet',
                      subtitle:
                          'Browse listings and reserve food to get started!',
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(8),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(order.listingTitle),
                        subtitle: Text('From ${order.providerName}'),
                        trailing: Text(
                          '\$${order.totalPrice.toStringAsFixed(2)}',
                        ),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.orderDetail,
                            arguments: order.id,
                          );
                        },
                      ),
                    );
                  },
                ),
        );
      },
      loading: () => const LoadingShimmer(height: 80),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _ProfileTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotUser = ref.watch(currentUserProvider);
    if (snapshotUser == null) return const SizedBox.shrink();

    // Use the live Firestore stream so profile updates show immediately.
    final user = ref.watch(userProvider(snapshotUser.id)).value ?? snapshotUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.profile),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(userProvider(user.id));
          try {
            await ref.read(userProvider(user.id).future);
          } catch (_) {}
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                backgroundImage: user.profileImage != null
                    ? NetworkImage(user.profileImage!)
                    : null,
                child: user.profileImage == null
                    ? Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                user.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: user.isProvider
                      ? AppColors.accent.withOpacity(0.1)
                      : user.isNGO
                      ? AppColors.completed.withOpacity(0.1)
                      : AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  user.isProvider
                      ? 'Food Provider'
                      : user.isNGO
                      ? 'NGO / Volunteer'
                      : 'Consumer',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: user.isProvider
                        ? AppColors.accent
                        : user.isNGO
                        ? AppColors.completed
                        : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (user.isProvider) ...[
                _ProfileMenuItem(
                  icon: Icons.dashboard_outlined,
                  title: 'Provider Dashboard',
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.providerDashboard),
                ),
              ],
              _ProfileMenuItem(
                icon: Icons.favorite_outline,
                title: 'Favorites',
                onTap: () {
                  // TODO: Implement favorites screen
                },
              ),
              _ProfileMenuItem(
                icon: Icons.chat_outlined,
                title: 'Messages',
                onTap: () => Navigator.pushNamed(context, AppRoutes.chat),
              ),
              _ProfileMenuItem(
                icon: Icons.info_outline,
                title: 'About SurplusBite',
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'SurplusBite',
                    applicationVersion: '1.0.0',
                    applicationIcon: const Icon(
                      Icons.eco,
                      size: 48,
                      color: AppColors.primary,
                    ),
                    children: [
                      const Text(
                        'Hyperlocal Food Waste & Surplus Redistribution Network',
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ref.read(authProvider.notifier).signOut();
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.logout, color: AppColors.error),
                  label: const Text(
                    'Sign Out',
                    style: TextStyle(color: AppColors.error),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
