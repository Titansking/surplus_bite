import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/listing_provider.dart';
import '../../models/listing_model.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/order_status_chip.dart';

class ListingDetailScreen extends ConsumerStatefulWidget {
  const ListingDetailScreen({super.key});

  @override
  ConsumerState<ListingDetailScreen> createState() =>
      _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  int _selectedImageIndex = 0;
  int _selectedQuantity = 1;

  @override
  Widget build(BuildContext context) {
    final listingId =
        ModalRoute.of(context)!.settings.arguments as String;
    final listingAsync = ref.watch(listingDetailProvider(listingId));
    final user = ref.watch(currentUserProvider);

    return listingAsync.when(
      data: (listing) {
        if (listing == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Listing')),
            body: const Center(child: Text('Listing not found')),
          );
        }
        return _buildDetail(listing, user?.id);
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Listing')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Listing')),
        body: Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildDetail(ListingModel listing, String? userId) {
    final isOwner = userId == listing.providerId;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (listing.images.isNotEmpty)
                    PageView.builder(
                      itemCount: listing.images.length,
                      onPageChanged: (i) =>
                          setState(() => _selectedImageIndex = i),
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => Scaffold(
                                  body: PhotoView(
                                    imageProvider: NetworkImage(
                                      listing.images[index],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          child: CachedNetworkImage(
                            imageUrl: listing.images[index],
                            fit: BoxFit.cover,
                          ),
                        );
                      },
                    )
                  else
                    Container(
                      color: AppColors.surface,
                      child: const Icon(
                        Icons.fastfood_outlined,
                        size: 80,
                        color: AppColors.textHint,
                      ),
                    ),
                  if (listing.images.length > 1)
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          listing.images.length,
                          (i) => Container(
                            width: i == _selectedImageIndex ? 24 : 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: i == _selectedImageIndex
                                  ? Colors.white
                                  : Colors.white.withOpacity( 0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          listing.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      OrderStatusChip(status: listing.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.store_outlined,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        listing.providerName,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.access_time,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${Formatters.relativeTime(listing.createdAt)} ago',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        Formatters.currency(listing.discountedPrice),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      if (listing.originalPrice > listing.discountedPrice) ...[
                        const SizedBox(width: 12),
                        Text(
                          Formatters.currency(listing.originalPrice),
                          style: TextStyle(
                            fontSize: 18,
                            color: AppColors.textHint,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity( 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            Formatters.discount(listing.discountPercent),
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (listing.originalPrice > listing.discountedPrice)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity( 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.savings_outlined,
                              color: AppColors.success, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'You save ${Formatters.currency(listing.originalPrice - listing.discountedPrice)} (${Formatters.discount(listing.discountPercent)})',
                            style: const TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  _buildInfoRow(Icons.category_outlined, 'Category',
                      listing.category),
                  _buildInfoRow(Icons.inventory_2_outlined, 'Available',
                      '${listing.quantity} ${listing.unit}'),
                  _buildInfoRow(
                    Icons.access_time,
                    'Pickup Window',
                    '${Formatters.time(listing.pickupStart)} - ${Formatters.time(listing.pickupEnd)}',
                  ),
                  if (listing.expiryDate != null)
                    _buildInfoRow(
                      Icons.event_outlined,
                      'Best Before',
                      Formatters.dateTime(listing.expiryDate!),
                      valueColor: listing.expiryDate!.isBefore(DateTime.now())
                          ? AppColors.error
                          : null,
                    ),
                  if (listing.pickupLocation.isNotEmpty)
                    _buildInfoRow(
                      Icons.location_on_outlined,
                      'Pickup Spot',
                      listing.pickupLocation,
                    ),
                  if (!isOwner && listing.providerPhone.isNotEmpty)
                    _buildInfoRow(
                      Icons.phone_outlined,
                      'Contact',
                      '+91 ${listing.providerPhone}',
                    ),
                  if (listing.address != null)
                    _buildInfoRow(Icons.map_outlined, 'Address',
                        listing.address!),
                  const SizedBox(height: 20),
                  const Text(
                    'Description',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    listing.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  if (listing.dietaryTags.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Dietary Info',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: listing.dietaryTags.map((tag) {
                        return Chip(
                          label: Text(tag, style: const TextStyle(fontSize: 12)),
                          backgroundColor:
                              AppColors.primary.withOpacity( 0.1),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: !isOwner && listing.isAvailable
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _selectedQuantity > 1
                              ? () => setState(() => _selectedQuantity--)
                              : null,
                          icon: const Icon(Icons.remove),
                        ),
                        Text(
                          '$_selectedQuantity',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          onPressed:
                              _selectedQuantity < listing.quantity
                                  ? () => setState(() => _selectedQuantity++)
                                  : null,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _reserveListing(listing),
                      icon: const Icon(Icons.shopping_bag_outlined),
                      label: Text(
                        'Reserve · ${Formatters.currency(listing.discountedPrice * _selectedQuantity)}',
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reserveListing(ListingModel listing) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      final orderData = {
        'listingId': listing.id,
        'listingTitle': listing.title,
        'buyerId': user.id,
        'buyerName': user.name,
        'providerId': listing.providerId,
        'providerName': listing.providerName,
        'providerPhone': listing.providerPhone,
        'pickupLocation': listing.pickupLocation,
        'quantity': _selectedQuantity,
        'totalPrice': listing.discountedPrice * _selectedQuantity,
        'status': 'pending',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };

      await FirebaseFirestore.instance.collection('orders').add(orderData);

      final newQty = listing.quantity - _selectedQuantity;
      await FirebaseFirestore.instance
          .collection('listings')
          .doc(listing.id)
          .update({
        'quantity': newQty,
        'status': newQty <= 0 ? 'reserved' : 'available',
        'updatedAt': Timestamp.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reservation placed successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
