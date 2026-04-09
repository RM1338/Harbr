import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/router/app_router.dart';

/// Onboarding screen — harbr wordmark, tagline, Get Started button
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 3),
              // Wordmark
              Text(
                'harbr',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 56,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your space. Reserved.',
                style: AppTextStyles.bodyLg.copyWith(color: AppColors.onSurfaceMuted),
              ),
              const Spacer(flex: 2),
              // Primary CTA
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => context.go(AppRoutes.signIn),
                  child: const Text('Get Started'),
                ),
              ),
              const SizedBox(height: 16),
              // Secondary link
              Center(
                child: GestureDetector(
                  onTap: () => context.go(AppRoutes.signIn),
                  child: Text(
                    'Already have an account? Sign in',
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
