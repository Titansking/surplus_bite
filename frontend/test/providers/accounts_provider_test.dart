import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:surplus_bite/models/local_account.dart';
import 'package:surplus_bite/providers/auth_provider.dart';

void main() {
  ProviderContainer container() => ProviderContainer(overrides: []);

  LocalAccount account(String uid, {String email = 'a@example.com'}) =>
      LocalAccount(uid: uid, email: email, name: 'User', provider: 'google.com');

  test('upsert keeps one entry per uid, most recent first', () {
    final c = container();
    addTearDown(c.dispose);

    final notifier = c.read(accountsProvider.notifier);
    notifier.upsert(account('1'));
    notifier.upsert(account('2', email: 'b@example.com'));
    expect(c.read(accountsProvider).length, 2);
    expect(c.read(accountsProvider).first.uid, '2');

    notifier.upsert(account('1'));
    expect(c.read(accountsProvider).length, 2);
    expect(c.read(accountsProvider).first.uid, '1');
  });

  test('remove drops the account', () {
    final c = container();
    addTearDown(c.dispose);

    final notifier = c.read(accountsProvider.notifier);
    notifier.upsert(account('1'));
    notifier.upsert(account('2'));
    notifier.remove('1');
    expect(c.read(accountsProvider).map((a) => a.uid), ['2']);
  });
}