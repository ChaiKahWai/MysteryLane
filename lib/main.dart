import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'presentation/screens/auth/welcome_screen.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/profile/reset_password_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseConfig.initialize();

  runApp(const MysteryLaneApp());
}

class MysteryLaneApp extends StatefulWidget {
  const MysteryLaneApp({super.key});

  @override
  State<MysteryLaneApp> createState() =>
      _MysteryLaneAppState();
}

class _MysteryLaneAppState extends State<MysteryLaneApp> {
  final GlobalKey<NavigatorState> navigatorKey =
  GlobalKey<NavigatorState>();

  StreamSubscription<AuthState>? _authSubscription;

  bool _handlingVerification = false;

  // Prevent the reset page from being opened more than once.
  bool _resetPasswordScreenOpen = false;

  @override
  void initState() {
    super.initState();

    _listenToAuthChanges();
  }

  // ============================================================
  // AUTH LISTENER
  // ============================================================

  void _listenToAuthChanges() {
    _authSubscription =
        SupabaseConfig.client.auth.onAuthStateChange.listen(
              (AuthState data) async {
            final AuthChangeEvent event = data.event;
            final Session? session = data.session;

            debugPrint('AUTH EVENT: $event');

            // ======================================================
            // PASSWORD RECOVERY
            // ======================================================

            if (event == AuthChangeEvent.passwordRecovery) {
              debugPrint(
                'PASSWORD RECOVERY EVENT DETECTED',
              );

              _openResetPasswordScreen();

              return;
            }

            // ======================================================
            // NORMAL AUTH
            // ======================================================

            if (session == null) {
              return;
            }

            final User user = session.user;

            // ======================================================
            // EMAIL VERIFICATION
            // ======================================================

            if ((event == AuthChangeEvent.signedIn ||
                event ==
                    AuthChangeEvent.initialSession) &&
                user.emailConfirmedAt != null) {
              await _handleVerifiedUser(user);
            }
          },
        );
  }

  // ============================================================
  // OPEN RESET PASSWORD SCREEN
  // ============================================================

  void _openResetPasswordScreen() {
    if (_resetPasswordScreenOpen) {
      return;
    }

    _resetPasswordScreenOpen = true;

    // Do NOT navigate directly inside the auth callback.
    //
    // Wait until Flutter has finished the current frame.
    WidgetsBinding.instance.addPostFrameCallback(
          (_) {
        if (!mounted) {
          _resetPasswordScreenOpen = false;
          return;
        }

        final NavigatorState? navigator =
            navigatorKey.currentState;

        if (navigator == null) {
          _resetPasswordScreenOpen = false;

          // Navigator may not be ready yet when app is launched
          // from the email link.
          Future<void>.delayed(
            const Duration(milliseconds: 300),
                () {
              if (mounted) {
                _openResetPasswordScreen();
              }
            },
          );

          return;
        }

        navigator
            .push(
          MaterialPageRoute(
            builder: (_) =>
            const ResetPasswordScreen(),
          ),
        )
            .then(
              (_) {
            _resetPasswordScreenOpen = false;
          },
        );
      },
    );
  }

  // ============================================================
  // EMAIL VERIFICATION HANDLER
  // ============================================================

  Future<void> _handleVerifiedUser(
      User user,
      ) async {
    if (_handlingVerification) {
      return;
    }

    // Very important:
    //
    // During password recovery Supabase creates/updates an auth
    // session. We don't want registration/profile creation logic
    // interfering with the recovery screen.
    if (_resetPasswordScreenOpen) {
      return;
    }

    _handlingVerification = true;

    try {
      final Map<String, dynamic>? existingProfile =
      await SupabaseConfig.client
          .from('profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      // Existing user.
      // Nothing needs to be created.
      if (existingProfile != null) {
        return;
      }

      final Map<String, dynamic> metadata =
          user.userMetadata ?? {};

      final String fullName =
          metadata['full_name']
              ?.toString()
              .trim() ??
              '';

      final String phoneNumber =
          metadata['phone_number']
              ?.toString()
              .trim() ??
              '';

      final String email =
          user.email ?? '';

      await SupabaseConfig.client
          .from('profiles')
          .insert({
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

      // This signOut belongs ONLY to your registration/email
      // verification flow.
      //
      // Password recovery NEVER comes here because the recovery
      // event returns earlier above.
      await SupabaseConfig.client.auth.signOut();

      if (!mounted) {
        return;
      }

      WidgetsBinding.instance.addPostFrameCallback(
            (_) {
          if (!mounted) {
            return;
          }

          navigatorKey.currentState
              ?.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) =>
              const LoginScreen(),
            ),
                (route) => false,
          );
        },
      );
    } on PostgrestException catch (error) {
      debugPrint(
        'PROFILE CREATION ERROR: ${error.message}',
      );
    } catch (error) {
      debugPrint(
        'VERIFICATION HANDLER ERROR: $error',
      );
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