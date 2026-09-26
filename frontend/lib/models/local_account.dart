class LocalAccount {
  final String uid;
  final String email;
  final String? name;
  final String? photoUrl;
  final String provider;

  const LocalAccount({
    required this.uid,
    required this.email,
    this.name,
    this.photoUrl,
    required this.provider,
  });

  bool get isGoogle => provider == 'google.com';

  factory LocalAccount.fromJson(Map<String, dynamic> json) {
    return LocalAccount(
      uid: json['uid'] as String,
      email: json['email'] as String? ?? '',
      name: json['name'] as String?,
      photoUrl: json['photoUrl'] as String?,
      provider: json['provider'] as String? ?? 'password',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'photoUrl': photoUrl,
      'provider': provider,
    };
  }
}