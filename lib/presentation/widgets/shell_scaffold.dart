import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../core/router/app_router.dart';
import '../providers/app_providers.dart';
import 'violation_banner.dart';

/// Persistent shell scaffold with bottom navigation (5 items — no overflow)
class ShellScaffold extends ConsumerStatefulWidget {
  final Widget child;
  const ShellScaffold({super.key, required this.child});

  @override
  ConsumerState<ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends ConsumerState<ShellScaffold> {
  bool _isOffline = false;

  // 5 tabs — fits any phone without overflow
  static const _tabs = [
    AppRoutes.home,
    AppRoutes.map,
    AppRoutes.bookings,
    AppRoutes.gate,
    AppRoutes.profile,
  ];

  static const _icons = [
    LucideIcons.layoutGrid,
    LucideIcons.map,
    LucideIcons.calendarDays,
    LucideIcons.doorOpen,
    LucideIcons.user,
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final idx = _tabs.indexOf(location);
    return idx < 0 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<ConnectivityResult>>>(connectivityProvider,
        (_, next) {
      final results = next.valueOrNull;
      if (results == null) return;
      final offline = results.every((r) => r == ConnectivityResult.none);
      if (offline != _isOffline) {
        setState(() => _isOffline = offline);
      }
    });

    final currentIndex = _currentIndex(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          if (_isOffline)
            SafeArea(
              bottom: false,
              child: ViolationBanner(
                message: 'No internet connection — data may be stale',
                isCritical: false,
                onDismiss: () => setState(() => _isOffline = false),
              ),
            ),
          Expanded(child: widget.child),
        ],
      ),
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
            // Each tab gets an equal share of the available width — no overflow
            children: List.generate(_tabs.length, (i) {
              final isActive = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => context.go(_tabs[i]),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    height: 56,
                    child: Center(
                      child: Icon(
                        _icons[i],
                        size: 22,
                        color: isActive
                            ? AppColors.navIconActive
                            : AppColors.navIconInactive,
                      ),
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
