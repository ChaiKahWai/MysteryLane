import 'package:flutter/material.dart';

import 'register_screen.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // =========================================================
                // BACKGROUND IMAGE
                // =========================================================
                Image.network(
                  'https://images.unsplash.com/photo-1596422846543-75c6fc197f07'
                      '?auto=format&fit=crop&w=1200&q=80',
                  fit: BoxFit.cover,

                  // If image cannot load
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFF0F172A),
                    );
                  },

                  // Loading screen while image is loading
                  loadingBuilder: (
                      context,
                      child,
                      loadingProgress,
                      ) {
                    if (loadingProgress == null) {
                      return child;
                    }

                    return Container(
                      color: const Color(0xFF0F172A),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),

                // =========================================================
                // DARK BLUE GRADIENT OVERLAY
                // =========================================================
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.fromRGBO(
                          0,
                          0,
                          0,
                          0.30,
                        ),
                        Color.fromRGBO(
                          15,
                          23,
                          42,
                          0.50,
                        ),
                        Color.fromRGBO(
                          2,
                          132,
                          199,
                          0.90,
                        ),
                      ],
                      stops: [
                        0.0,
                        0.50,
                        1.0,
                      ],
                    ),
                  ),
                ),

                // =========================================================
                // WELCOME PAGE CONTENT
                // =========================================================
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      24,
                      30,
                      24,
                      34,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // -------------------------------------------------
                        // SMALL LABEL
                        // -------------------------------------------------
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(
                              alpha: 0.10,
                            ),
                            borderRadius:
                            BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(
                                alpha: 0.20,
                              ),
                            ),
                          ),
                          child: const Text(
                            'DISCOVERY CHRONICLES • MALAYSIA EXPEDITIONS',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFE0F2FE),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // -------------------------------------------------
                        // APP NAME
                        // -------------------------------------------------
                        const Text(
                          'MysteryLane',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 46,
                            height: 1,
                            fontFamily: 'serif',
                            fontWeight: FontWeight.w900,
                            shadows: [
                              Shadow(
                                blurRadius: 8,
                                color: Colors.black38,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // -------------------------------------------------
                        // SUBTITLE
                        // -------------------------------------------------
                        const Padding(
                          padding:
                          EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'Explore hidden gems across Malaysia. '
                                'Your mystery adventure starts here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFE0F2FE),
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              height: 1.5,
                            ),
                          ),
                        ),

                        const SizedBox(height: 44),

                        // =================================================
                        // CREATE ACCOUNT BUTTON
                        // =================================================
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                  const RegisterScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor:
                              const Color(0xFF0284C7),
                              elevation: 8,
                              shadowColor: Colors.black26,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'CREATE ACCOUNT',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 3,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // =================================================
                        // SIGN IN BUTTON
                        // =================================================
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                  const LoginScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                              const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              elevation: 8,
                              shadowColor: Colors.black26,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(16),
                                side: BorderSide(
                                  color:
                                  Colors.white.withValues(
                                    alpha: 0.30,
                                  ),
                                ),
                              ),
                            ),
                            child: const Text(
                              'SIGN IN',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}