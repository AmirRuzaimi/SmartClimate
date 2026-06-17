import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'main.dart'; // Imports MainNavigationShell gatekeeper paths cleanly

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation; // Secondary calculation engine for the spinning sun effect
  Timer? _routingTimer;

  @override
  void initState() {
    super.initState();

    // ─── INITIALIZE SYNCED ANIMATION DRIVER ──────────────────────────────────
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200), // Slightly prolonged for smoother continuous spin
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn), // Completes fade-in early
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.70, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack), // Elastic entry scaling
      ),
    );

    // ─── SPINNING ENGINE LOGIC ────────────────────────────────────────────────
    // Uses a full 1.0 cycle which RotationTransition interprets as a beautiful 360° turn
    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 1.0, curve: Curves.linear), // Uniform speed
      ),
    );

    // Explicitly command the controller to loop the rotation spinning continuously!
    _animationController.repeat();

    // ─── BACKGROUND SESSION VERIFICATION GATEWAY ──────────────────────────────
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routingTimer = Timer(const Duration(milliseconds: 2800), () {
        if (!mounted) return;

        final User? currentUser = FirebaseAuth.instance.currentUser;

        if (currentUser != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MainNavigationShell(
                onLogout: () {
                  FirebaseAuth.instance.signOut();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen(
                      onLoginSuccess: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => MainNavigationShell(
                            onLogout: () => FirebaseAuth.instance.signOut(),
                          )),
                        );
                      },
                    )),
                        (route) => false,
                  );
                },
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => LoginScreen(
                onLoginSuccess: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MainNavigationShell(
                        onLogout: () => FirebaseAuth.instance.signOut(),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _routingTimer?.cancel();
    _animationController.dispose(); // Stops the loops instantly to safe-keep RAM health
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.orange.shade300, Colors.orange.shade600],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ─── NESTED ROTATION WRAPPER FOR THE SUN ICON ────────────────
                        RotationTransition(
                          turns: _rotationAnimation,
                          child: const Icon(
                              Icons.wb_sunny_rounded, // Using rounded style for a smoother look
                              size: 96,
                              color: Colors.white
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "SmartClimate",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "SunCare Community Network",
                          style: TextStyle(
                            color: Colors.orange.shade100,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 60),

                // Native indicator showing system verification behavior
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white70),
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