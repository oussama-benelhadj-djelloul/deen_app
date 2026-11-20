import 'package:flutter/material.dart';
import 'home_page.dart';
import 'design.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Slide from slightly above (negative y) to original position
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.2), // start slightly above
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Fade in
    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward(); // start the animation
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isNavigating = false;

  void _goToHomePage() {
    // Ignore extra taps while the transition is running
    if (_isNavigating) return;
    _isNavigating = true;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LocationPermissionPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Quick, simple fade
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _goToHomePage,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            // Centered content with animation
            Expanded(
              child: Center(
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "🌿 مرحبا بك",
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          "في تطبيق دين",
                          style: TextStyle(fontSize: 32, color: AppColors.zinc400),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom text
            Padding(
              padding: EdgeInsets.only(bottom: 42),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  "اضغط في أي مكان للبدء.",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.zinc400,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
