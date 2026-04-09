import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/router/app_router.dart';

/// Persistent shell scaffold with bottom navigation
class ShellScaffold extends ConsumerWidget {
  final Widget child;
  const ShellScaffold({super.key, required this.child});

  static const _tabs = [
    AppRoutes.home,
    AppRoutes.reservation,
    AppRoutes.bookings,
    AppRoutes.updates,
    AppRoutes.profile,
  ];

  static final _icons = [
    LucideIcons.layoutGrid,
    LucideIcons.parkingSquare,
    LucideIcons.calendarDays,
    LucideIcons.activity,
    LucideIcons.user,
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final idx = _tabs.indexOf(location);
    return idx < 0 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = _currentIndex(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: child,
      bottomNavigationBar: Container(
        height: 64,
        decoration: const BoxDecoration(
          color: AppColors.navBackground,
          border: Border(
            top: BorderSide(color: AppColors.border, width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_icons.length, (i) {
              final isActive = i == currentIndex;
              return GestureDetector(
                onTap: () => context.go(_tabs[i]),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: Center(
                    child: Icon(
                      _icons[i],
                      size: 20,
                      color: isActive
                          ? AppColors.navIconActive
                          : AppColors.navIconInactive,
                      // strokeWidth equivalent via OpticalSize — Lucide uses outline style
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
