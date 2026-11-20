import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'design.dart';
import 'onboarding_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppTheme.isDarkNotifier,
      builder: (context, isDark, _) {
        final brightness = isDark ? Brightness.dark : Brightness.light;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            fontFamily: 'IBMPlexArabic',
            brightness: brightness,
            scaffoldBackgroundColor: AppColors.background,
          ),
          // Status bar icons follow the mode (dark icons on light pages)
          builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: isDark
                ? SystemUiOverlayStyle.light.copyWith(
                    statusBarColor: Colors.transparent,
                  )
                : SystemUiOverlayStyle.dark.copyWith(
                    statusBarColor: Colors.transparent,
                  ),
            child: child!,
          ),
          home: const OnboardingScreen(),
        );
      },
    );
  }
}
