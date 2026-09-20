import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String? profileImage;
  final String? businessName;
  final String? businessDescription;
  final GeoPoint? location;
  final String? address;
  final double rating;
  final int totalRatings;
  final List<String> favorites;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    required this.role,
    this.profileImage,
    this.businessName,
    this.businessDescription,
    this.location,
    this.address,
    this.rating = 0.0,
    this.totalRatings = 0,
    this.favorites = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel.fromMap(data, id: doc.id);
  }

  factory UserModel.fromMap(Map<String, dynamic> data, {required String id}) {
    return UserModel(
      id: id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] ?? 'consumer',
      profileImage: data['profileImage'],
      businessName: data['businessName'],
      businessDescription: data['businessDescription'],
      location: data['location'],
      address: data['address'],
      rating: (data['rating'] ?? 0.0).toDouble(),
      totalRatings: data['totalRatings'] ?? 0,
      favorites: List<String>.from(data['favorites'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'profileImage': profileImage,
      'businessName': businessName,
      'businessDescription': businessDescription,
      'location': location,
      'address': address,
      'rating': rating,
      'totalRatings': totalRatings,
      'favorites': favorites,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  UserModel copyWith({
    String? name,
    String? phone,
    String? role,
    String? profileImage,
    String? businessName,
    String? businessDescription,
    GeoPoint? location,
    String? address,
    double? rating,
    int? totalRatings,
    List<String>? favorites,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      profileImage: profileImage ?? this.profileImage,
      businessName: businessName ?? this.businessName,
      businessDescription: businessDescription ?? this.businessDescription,
      location: location ?? this.location,
      address: address ?? this.address,
      rating: rating ?? this.rating,
      totalRatings: totalRatings ?? this.totalRatings,
      favorites: favorites ?? this.favorites,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  bool get isProvider => role == 'provider';
  bool get isNGO => role == 'ngo';
  bool get isConsumer => role == 'consumer';

  @override
  List<Object?> get props => [id, name, email, role, rating, favorites];
}
