import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../models/order_model.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/order_status_chip.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final orderId = ModalRoute.of(context)!.settings.arguments as String;
    final orderAsync = ref.watch(orderDetailProvider(orderId));
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Order Details')),
      body: orderAsync.when(
        data: (order) {
          if (order == null) {
            return const Center(child: Text('Order not found'));
          }
          return _buildOrderDetail(order, user?.id);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildOrderDetail(OrderModel order, String? userId) {
    final isProvider = userId == order.providerId;
    final isBuyer = userId == order.buyerId;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(orderDetailProvider(order.id));
        try {
          await ref.read(orderDetailProvider(order.id).future);
        } catch (_) {}
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.listingTitle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        OrderStatusChip(status: order.status),
                      ],
                    ),
                    const Divider(height: 32),
                    _buildInfoTile(
                      Icons.shopping_bag_outlined,
                      'Quantity',
                      '${order.quantity} items',
                    ),
                    _buildInfoTile(
                      Icons.currency_rupee,
                      'Total Price',
                      Formatters.currency(order.totalPrice),
                    ),
                    _buildInfoTile(
                      Icons.person_outlined,
                      isProvider ? 'Buyer' : 'Provider',
                      isProvider ? order.buyerName : order.providerName,
                    ),
                    _buildInfoTile(
                      Icons.access_time,
                      'Ordered',
                      Formatters.dateTime(order.createdAt),
                    ),
                    if (order.pickupTime != null)
                      _buildInfoTile(
                        Icons.schedule,
                        'Pickup Time',
                        Formatters.dateTime(order.pickupTime!),
                      ),
                    if (order.cancellationReason != null) ...[
                      const Divider(),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: AppColors.error,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Cancelled: ${order.cancellationReason}',
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildActionButtons(order, isProvider, isBuyer),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(OrderModel order, bool isProvider, bool isBuyer) {
    if (order.isCancelled || order.isCompleted) return const SizedBox.shrink();

    return Column(
      children: [
        if (isProvider && order.isPending) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _updateStatus(order.id, 'confirmed'),
              child: const Text('Confirm Order'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _cancelOrder(order.id),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
              ),
              child: const Text(
                'Decline',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ),
        ],
        if (isProvider && order.isConfirmed) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _updateStatus(order.id, 'picked_up'),
              child: const Text('Mark as Picked Up'),
            ),
          ),
        ],
        if (isBuyer && order.isPickedUp) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _updateStatus(order.id, 'completed'),
              child: const Text('Confirm Receipt'),
            ),
          ),
        ],
        if (isBuyer && (order.isPending || order.isConfirmed)) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _cancelOrder(order.id),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
              ),
              child: const Text(
                'Cancel Order',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _updateStatus(String orderId, String status) async {
    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update(
        {'status': status, 'updatedAt': Timestamp.now()},
      );
      ref.invalidate(orderDetailProvider(orderId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order ${status.replaceAll('_', ' ')}!'),
            backgroundColor: AppColors.success,
          ),
        );
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

  Future<void> _cancelOrder(String orderId) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Cancel Order'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Reason (optional)'),
            maxLines: 2,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Cancel Order'),
            ),
          ],
        );
      },
    );

    if (reason != null) {
      try {
        await FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId)
            .update({
              'status': 'cancelled',
              'cancellationReason': reason.isNotEmpty
                  ? reason
                  : 'No reason given',
              'updatedAt': Timestamp.now(),
            });
        ref.invalidate(orderDetailProvider(orderId));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order cancelled'),
              backgroundColor: AppColors.error,
            ),
          );
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
}
