import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class ListingModel extends Equatable {
  final String id;
  final String providerId;
  final String providerName;
  final String providerPhone;
  final String title;
  final String description;
  final String category;
  final double originalPrice;
  final double discountedPrice;
  final int quantity;
  final String unit;
  final List<String> images;
  final GeoPoint location;
  final String? address;
  final String pickupLocation;
  final DateTime pickupStart;
  final DateTime pickupEnd;
  final DateTime? expiryDate;
  final String status;
  final List<String> dietaryTags;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ListingModel({
    required this.id,
    required this.providerId,
    required this.providerName,
    this.providerPhone = '',
    required this.title,
    required this.description,
    required this.category,
    required this.originalPrice,
    required this.discountedPrice,
    required this.quantity,
    required this.unit,
    this.images = const [],
    required this.location,
    this.address,
    this.pickupLocation = '',
    required this.pickupStart,
    required this.pickupEnd,
    this.expiryDate,
    this.status = 'available',
    this.dietaryTags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory ListingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ListingModel(
      id: doc.id,
      providerId: data['providerId'] ?? '',
      providerName: data['providerName'] ?? '',
      providerPhone: data['providerPhone'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      originalPrice: (data['originalPrice'] ?? 0.0).toDouble(),
      discountedPrice: (data['discountedPrice'] ?? 0.0).toDouble(),
      quantity: data['quantity'] ?? 0,
      unit: data['unit'] ?? 'pieces',
      images: List<String>.from(data['images'] ?? []),
      location: data['location'] ?? const GeoPoint(0, 0),
      address: data['address'],
      pickupLocation: data['pickupLocation'] ?? '',
      pickupStart:
          (data['pickupStart'] as Timestamp?)?.toDate() ?? DateTime.now(),
      pickupEnd:
          (data['pickupEnd'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiryDate: (data['expiryDate'] as Timestamp?)?.toDate(),
      status: data['status'] ?? 'available',
      dietaryTags: List<String>.from(data['dietaryTags'] ?? []),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
          (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'providerId': providerId,
      'providerName': providerName,
      'providerPhone': providerPhone,
      'title': title,
      'description': description,
      'category': category,
      'originalPrice': originalPrice,
      'discountedPrice': discountedPrice,
      'quantity': quantity,
      'unit': unit,
      'images': images,
      'location': location,
      'address': address,
      'pickupLocation': pickupLocation,
      'pickupStart': Timestamp.fromDate(pickupStart),
      'pickupEnd': Timestamp.fromDate(pickupEnd),
      if (expiryDate != null) 'expiryDate': Timestamp.fromDate(expiryDate!),
      'status': status,
      'dietaryTags': dietaryTags,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  ListingModel copyWith({
    String? title,
    String? description,
    String? category,
    double? originalPrice,
    double? discountedPrice,
    int? quantity,
    String? unit,
    List<String>? images,
    GeoPoint? location,
    String? address,
    String? pickupLocation,
    DateTime? pickupStart,
    DateTime? pickupEnd,
    DateTime? expiryDate,
    String? status,
    List<String>? dietaryTags,
  }) {
    return ListingModel(
      id: id,
      providerId: providerId,
      providerName: providerName,
      providerPhone: providerPhone,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      originalPrice: originalPrice ?? this.originalPrice,
      discountedPrice: discountedPrice ?? this.discountedPrice,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      images: images ?? this.images,
      location: location ?? this.location,
      address: address ?? this.address,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      pickupStart: pickupStart ?? this.pickupStart,
      pickupEnd: pickupEnd ?? this.pickupEnd,
      expiryDate: expiryDate ?? this.expiryDate,
      status: status ?? this.status,
      dietaryTags: dietaryTags ?? this.dietaryTags,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  double get discountPercent => originalPrice > 0
      ? ((originalPrice - discountedPrice) / originalPrice * 100)
      : 0;

  bool get isAvailable => status == 'available';
  bool get isExpired {
    final now = DateTime.now();
    if (expiryDate != null && expiryDate!.isBefore(now)) return true;
    return pickupEnd.isBefore(now);
  }

  double distanceFrom(GeoPoint userLocation) {
    const double earthRadius = 6371;
    final double lat1 = location.latitude * (math.pi / 180);
    final double lat2 = userLocation.latitude * (math.pi / 180);
    final double dLat =
        (userLocation.latitude - location.latitude) * (math.pi / 180);
    final double dLon =
        (userLocation.longitude - location.longitude) * (math.pi / 180);
    final double a = (dLat / 2) * (dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * (dLon / 2) * (dLon / 2);
    final double c = 2 * math.asin(math.sqrt(a));
    return earthRadius * c;
  }

  @override
  List<Object?> get props => [id, providerId, title, status, quantity];
}
