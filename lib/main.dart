import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'presentation/screens/auth/welcome_screen.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/reset_password_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseConfig.initialize();

  runApp(const MysteryLaneApp());
}

class MysteryLaneApp extends StatefulWidget {
  const MysteryLaneApp({super.key});

  @override
  State<MysteryLaneApp> createState() => _MysteryLaneAppState();
}

class _MysteryLaneAppState extends State<MysteryLaneApp> {
  final GlobalKey<NavigatorState> navigatorKey =
  GlobalKey<NavigatorState>();

  StreamSubscription<AuthState>? _authSubscription;

  bool _handlingVerification = false;

  @override
  void initState() {
    super.initState();

    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _authSubscription =
        SupabaseConfig.client.auth.onAuthStateChange.listen(
              (data) async {
            final AuthChangeEvent event = data.event;
            final Session? session = data.session;

            debugPrint('AUTH EVENT: $event');

            // Handle Password Recovery Event
            if (event == AuthChangeEvent.passwordRecovery) {
              debugPrint('PASSWORD RECOVERY EVENT DETECTED');
              _navigateToResetPassword();
              return;
            }

            if (session == null) {
              return;
            }

            final user = session.user;

            // Handle email verification flow:
            if ((event == AuthChangeEvent.signedIn ||
                event == AuthChangeEvent.initialSession) &&
                user.emailConfirmedAt != null) {
              await _handleVerifiedUser(user);
            }
          },
        );
  }

  void _navigateToResetPassword() {
    navigatorKey.currentState?.pushReplacement(
      MaterialPageRoute(
        builder: (context) => const ResetPasswordScreen(),
      ),
    );
  }

  Future<void> _handleVerifiedUser(User user) async {
    if (_handlingVerification) {
      return;
    }

    _handlingVerification = true;

    try {
      final existingProfile =
      await SupabaseConfig.client
          .from('profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (existingProfile == null) {
        final metadata = user.userMetadata ?? {};
        final fullName = metadata['full_name']?.toString().trim() ?? '';
        final phoneNumber = metadata['phone_number']?.toString().trim() ?? '';
        final email = user.email ?? '';

        await SupabaseConfig.client.from('profiles').insert({
          'id': user.id,
          'full_name': fullName,
          'email': email,
          'phone_number': phoneNumber,
          'profile_picture_url': null,
          'language_preference': 'English',
          'current_city': null,
          'progress_level': 1,
          'exploration_points': 0,
          'free_redraw_credits': 0,
          'team_status': null,
        });

        await SupabaseConfig.client.auth.signOut();

        final context = navigatorKey.currentContext;
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Email verified successfully. Please log in.',
              ),
              duration: Duration(seconds: 4),
            ),
          );

          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const LoginScreen(),
            ),
                (route) => false,
          );
        }
      }
    } on PostgrestException catch (error) {
      debugPrint('PROFILE CREATION ERROR: ${error.message}');
    } catch (error) {
      debugPrint('VERIFICATION HANDLER ERROR: $error');
    } finally {
      _handlingVerification = false;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'MYsteryLane',
      home: const WelcomeScreen(),
    );
  }
}