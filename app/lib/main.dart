import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
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
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Required once before any Google Sign-In call (google_sign_in >= 7).
  await GoogleSignIn.instance.initialize();

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
      // Rebuild the Navigator whenever the auth status flips so a restored
      // session (cold start) or a fresh login lands on the right screen.
      key: ValueKey(authState.status),
      title: 'SurplusBite',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: _getInitialRoute(authState),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case AppRoutes.splash:
            return MaterialPageRoute(builder: (_) => const _SplashScreen());
          case AppRoutes.login:
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case AppRoutes.register:
            return MaterialPageRoute(builder: (_) => const RegisterScreen());
          case AppRoutes.roleSelection:
            return MaterialPageRoute(
              builder: (_) => const RoleSelectionScreen(),
              settings: settings,
            );
          case AppRoutes.home:
            return MaterialPageRoute(builder: (_) => const HomeScreen());
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
            return MaterialPageRoute(builder: (_) => const ProfileScreen());
          case AppRoutes.providerDashboard:
            return MaterialPageRoute(
              builder: (_) => const ProviderDashboardScreen(),
            );
          case AppRoutes.chat:
            return MaterialPageRoute(builder: (_) => const ChatScreen());
          default:
            return MaterialPageRoute(builder: (_) => const LoginScreen());
        }
      },
    );
  }

  String _getInitialRoute(AuthState authState) {
    switch (authState.status) {
      case AuthStatus.authenticated:
        return AppRoutes.home;
      case AuthStatus.loading:
      case AuthStatus.unauthenticated:
      case AuthStatus.error:
        return AppRoutes.login; // login screen shows the loading spinner
      case AuthStatus.initial:
        // Session is being restored from the platform; hold on a splash.
        return AppRoutes.splash;
    }
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.eco, size: 72, color: AppColors.primary),
            SizedBox(height: 16),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
