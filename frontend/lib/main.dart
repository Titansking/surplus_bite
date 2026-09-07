import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'providers/auth_provider.dart';
import 'services/notification_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/role_selection_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/listing/create_listing_screen.dart';
import 'screens/listing/listing_detail_screen.dart';
import 'screens/listing/edit_listing_screen.dart';
import 'screens/orders/order_detail_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/provider_dashboard_screen.dart';
import 'screens/chat/chat_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize notifications (free FCM)
  final notificationService = NotificationService();
  await notificationService.initialize();
  notificationService.handleBackgroundMessage();

  runApp(const ProviderScope(child: SurplusBiteApp()));
}

class SurplusBiteApp extends ConsumerWidget {
  const SurplusBiteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'SurplusBite',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: _getInitialRoute(authState),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case AppRoutes.login:
            return MaterialPageRoute(
              builder: (_) => const LoginScreen(),
            );
          case AppRoutes.register:
            return MaterialPageRoute(
              builder: (_) => const RegisterScreen(),
            );
          case AppRoutes.roleSelection:
            return MaterialPageRoute(
              builder: (_) => const RoleSelectionScreen(),
              settings: settings,
            );
          case AppRoutes.home:
            return MaterialPageRoute(
              builder: (_) => const HomeScreen(),
            );
          case AppRoutes.createListing:
            return MaterialPageRoute(
              builder: (_) => const CreateListingScreen(),
            );
          case AppRoutes.listingDetail:
            return MaterialPageRoute(
              builder: (_) => const ListingDetailScreen(),
              settings: settings,
            );
          case AppRoutes.editListing:
            return MaterialPageRoute(
              builder: (_) => const EditListingScreen(),
              settings: settings,
            );
          case AppRoutes.orderDetail:
            return MaterialPageRoute(
              builder: (_) => const OrderDetailScreen(),
              settings: settings,
            );
          case AppRoutes.profile:
            return MaterialPageRoute(
              builder: (_) => const ProfileScreen(),
            );
          case AppRoutes.providerDashboard:
            return MaterialPageRoute(
              builder: (_) => const ProviderDashboardScreen(),
            );
          case AppRoutes.chat:
            return MaterialPageRoute(
              builder: (_) => const ChatScreen(),
            );
          default:
            return MaterialPageRoute(
              builder: (_) => const LoginScreen(),
            );
        }
      },
    );
  }

  String _getInitialRoute(AuthState authState) {
    switch (authState.status) {
      case AuthStatus.authenticated:
        return AppRoutes.home;
      case AuthStatus.loading:
        return AppRoutes.login; // Shows loading in login screen
      default:
        return AppRoutes.login;
    }
  }
}
