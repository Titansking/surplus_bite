import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';

class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  String? _selectedRole;

  final List<Map<String, dynamic>> _roles = [
    {
      'role': AppConstants.roleConsumer,
      'title': 'Food Consumer',
      'description': 'Find and rescue surplus food from local businesses at discounted prices',
      'icon': Icons.person_outlined,
      'color': AppColors.primary,
    },
    {
      'role': AppConstants.roleProvider,
      'title': 'Food Provider',
      'description': 'List your surplus food, reduce waste, and earn from what would be discarded',
      'icon': Icons.store_outlined,
      'color': AppColors.accent,
    },
    {
      'role': AppConstants.roleNGO,
      'title': 'NGO / Volunteer',
      'description': 'Collect surplus food in bulk to distribute to communities in need',
      'icon': Icons.volunteer_activism_outlined,
      'color': AppColors.completed,
    },
  ];

  void _selectRole() {
    if (_selectedRole == null) return;

    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    ref.read(authProvider.notifier).signUp(
          args['email'],
          args['password'],
          args['name'],
          _selectedRole!,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/home',
          (route) => false,
        );
      } else if (next.status == AuthStatus.error && next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Choose Your Role')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hi ${args['name']}!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'How do you want to use SurplusBite?',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: ListView.separated(
                itemCount: _roles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final role = _roles[index];
                  final isSelected = _selectedRole == role['role'];
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedRole = role['role']);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (role['color'] as Color).withOpacity( 0.1)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? role['color'] as Color
                              : AppColors.divider,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (role['color'] as Color).withOpacity( 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              role['icon'] as IconData,
                              color: role['color'] as Color,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  role['title'] as String,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  role['description'] as String,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: role['color'] as Color,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _selectedRole != null && authState.status != AuthStatus.loading
                    ? _selectRole
                    : null,
                child: authState.status == AuthStatus.loading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Get Started'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
