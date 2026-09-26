import 'package:flutter_test/flutter_test.dart';
import 'package:surplus_bite/models/local_account.dart';

void main() {
  const account = LocalAccount(
    uid: 'uid-123',
    email: 'alice@example.com',
    name: 'Alice',
    photoUrl: 'https://example.com/alice.png',
    provider: 'google.com',
  );

  test('fromJson/toJson round-trips all fields', () {
    final decoded = LocalAccount.fromJson(account.toJson());
    expect(decoded.uid, 'uid-123');
    expect(decoded.email, 'alice@example.com');
    expect(decoded.name, 'Alice');
    expect(decoded.photoUrl, 'https://example.com/alice.png');
    expect(decoded.provider, 'google.com');
    expect(decoded.isGoogle, isTrue);
  });

  test('fromJson tolerates missing optional fields', () {
    final decoded = LocalAccount.fromJson(const {
      'uid': 'uid-1',
      'email': 'bob@example.com',
    });
    expect(decoded.name, isNull);
    expect(decoded.photoUrl, isNull);
    expect(decoded.provider, 'password');
    expect(decoded.isGoogle, isFalse);
  });
}