import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class OrderModel extends Equatable {
  final String id;
  final String listingId;
  final String listingTitle;
  final String buyerId;
  final String buyerName;
  final String providerId;
  final String providerName;
  final int quantity;
  final double totalPrice;
  final String status;
  final DateTime? pickupTime;
  final String? cancellationReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OrderModel({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.buyerId,
    required this.buyerName,
    required this.providerId,
    required this.providerName,
    required this.quantity,
    required this.totalPrice,
    this.status = 'pending',
    this.pickupTime,
    this.cancellationReason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrderModel(
      id: doc.id,
      listingId: data['listingId'] ?? '',
      listingTitle: data['listingTitle'] ?? '',
      buyerId: data['buyerId'] ?? '',
      buyerName: data['buyerName'] ?? '',
      providerId: data['providerId'] ?? '',
      providerName: data['providerName'] ?? '',
      quantity: data['quantity'] ?? 0,
      totalPrice: (data['totalPrice'] ?? 0.0).toDouble(),
      status: data['status'] ?? 'pending',
      pickupTime: (data['pickupTime'] as Timestamp?)?.toDate(),
      cancellationReason: data['cancellationReason'],
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
          (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'listingId': listingId,
      'listingTitle': listingTitle,
      'buyerId': buyerId,
      'buyerName': buyerName,
      'providerId': providerId,
      'providerName': providerName,
      'quantity': quantity,
      'totalPrice': totalPrice,
      'status': status,
      'pickupTime':
          pickupTime != null ? Timestamp.fromDate(pickupTime!) : null,
      'cancellationReason': cancellationReason,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  OrderModel copyWith({
    int? quantity,
    double? totalPrice,
    String? status,
    DateTime? pickupTime,
    String? cancellationReason,
  }) {
    return OrderModel(
      id: id,
      listingId: listingId,
      listingTitle: listingTitle,
      buyerId: buyerId,
      buyerName: buyerName,
      providerId: providerId,
      providerName: providerName,
      quantity: quantity ?? this.quantity,
      totalPrice: totalPrice ?? this.totalPrice,
      status: status ?? this.status,
      pickupTime: pickupTime ?? this.pickupTime,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isPickedUp => status == 'picked_up';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  @override
  List<Object?> get props => [id, listingId, buyerId, status, quantity];
}
