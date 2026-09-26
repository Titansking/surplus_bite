import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../models/local_account.dart';
import '../../providers/auth_provider.dart';

class AccountSwitcherSheet extends ConsumerStatefulWidget {
  const AccountSwitcherSheet({super.key});

  @override
  ConsumerState<AccountSwitcherSheet> createState() =>
      _AccountSwitcherSheetState();
}

class _AccountSwitcherSheetState extends ConsumerState<AccountSwitcherSheet> {
  bool _busy = false;

  Future<void> _switchToGoogle() async {
    if (_busy) return;
    setState(() => _busy = true);
    await ref.read(authProvider.notifier).switchGoogleAccount();
    _finishSwitch();
  }

  Future<void> _switchToEmail(LocalAccount account) async {
    if (_busy) return;
    final password = await _promptPassword(account);
    if (password == null) return;
    setState(() => _busy = true);
    await ref
        .read(authProvider.notifier)
        .switchToEmailAccount(account.email, password);
    _finishSwitch();
  }

  Future<String?> _promptPassword(LocalAccount account) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Enter Password'),
          content: TextField(
            controller: controller,
            obscureText: true,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Password for ${account.email}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Sign In'),
            ),
          ],
        );
      },
    );
  }

  void _finishSwitch() {
    if (!mounted) return;
    final auth = ref.read(authProvider);
    if (auth.status == AuthStatus.error && auth.error != null) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error!), backgroundColor: AppColors.error),
      );
    } else if (auth.status == AuthStatus.authenticated) {
      Navigator.pop(context);
    } else {
      setState(() => _busy = false);
    }
  }

  void _removeAccount(LocalAccount account) {
    ref.read(authProvider.notifier).removeLocalAccount(account.uid);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed ${account.name ?? account.email}'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final accounts = ref.watch(accountsProvider);
    final currentUid = auth.user?.id;

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Text(
                'Accounts',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            if (accounts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No saved accounts yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              ...accounts.map(
                (account) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    backgroundImage: account.photoUrl != null
                        ? NetworkImage(account.photoUrl!)
                        : null,
                    child: account.photoUrl == null
                        ? Text(
                            (account.name?.isNotEmpty == true
                                    ? account.name!.characters.first
                                    : account.email.isNotEmpty
                                    ? account.email[0].toUpperCase()
                                    : '?'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                  ),
                  title: Text(
                    account.name?.isNotEmpty == true
                        ? account.name!
                        : account.email,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${account.email}  •  ${account.isGoogle ? 'Google' : 'Email'}',
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing:
                      currentUid == account.uid
                      ? const Icon(
                          Icons.check_circle,
                          color: AppColors.primary,
                        )
                      : IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Remove account',
                          onPressed: _busy ? null : () => _removeAccount(account),
                        ),
                  onTap:
                      currentUid == account.uid || _busy
                      ? null
                      : () => account.isGoogle
                            ? _switchToGoogle()
                            : _switchToEmail(account),
                ),
              ),
            const Divider(),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Icon(Icons.add, color: Colors.white),
              ),
              title: const Text('Add another account'),
              subtitle: const Text('Sign in with a different Google account'),
              enabled: !_busy,
              onTap: _switchToGoogle,
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text(
                'Sign Out',
                style: TextStyle(color: AppColors.error),
              ),
              enabled: !_busy,
              onTap: () {
                Navigator.pop(context);
                ref.read(authProvider.notifier).signOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}