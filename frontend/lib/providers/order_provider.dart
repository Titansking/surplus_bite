import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order_model.dart';
import '../providers/auth_provider.dart';

final buyerOrdersProvider =
    StreamProvider.family<List<OrderModel>, String>((ref, buyerId) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.buyerOrders(buyerId);
});

final providerOrdersProvider =
    StreamProvider.family<List<OrderModel>, String>((ref, providerId) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.providerOrders(providerId);
});

final orderDetailProvider =
    FutureProvider.family<OrderModel?, String>((ref, orderId) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getOrder(orderId);
});

final providerStatsProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, providerId) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getProviderStats(providerId);
});
