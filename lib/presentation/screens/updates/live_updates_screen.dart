import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/app_providers.dart';
import '../../widgets/error_banner.dart';
import '../../../domain/entities/parking_event.dart';

class LiveUpdatesScreen extends ConsumerStatefulWidget {
  const LiveUpdatesScreen({super.key});

  @override
  ConsumerState<LiveUpdatesScreen> createState() => _LiveUpdatesScreenState();
}

class _LiveUpdatesScreenState extends ConsumerState<LiveUpdatesScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  IconData _eventIcon(ParkingEvent event) {
    switch (event.type) {
      case EventType.violation:
        return LucideIcons.alertTriangle;
      case EventType.noShow:
        return LucideIcons.userX;
      case EventType.reservation:
        return LucideIcons.calendarCheck;
      case EventType.sensor:
        return LucideIcons.radio;
      case EventType.auth:
        return LucideIcons.shieldCheck;
      default:
        return LucideIcons.bell;
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Text('Live Updates', style: AppTextStyles.headlineMd),
            const SizedBox(width: 12),
            // Pulsing LIVE indicator
            FadeTransition(
              opacity: _pulseAnimation,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'LIVE',
                      style: AppTextStyles.labelSm.copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: eventsAsync.when(
        data: (events) {
          if (events.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.activity, size: 48, color: AppColors.onSurfaceDim),
                  const SizedBox(height: 16),
                  Text('No events yet', style: AppTextStyles.bodyLg),
                  const SizedBox(height: 8),
                  Text('Events will appear here in real-time', style: AppTextStyles.bodySm),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            itemCount: events.length,
            itemBuilder: (_, i) => _EventRow(event: events[i], icon: _eventIcon(events[i])),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => ErrorBanner(message: 'Unable to stream events. $e'),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final ParkingEvent event;
  final IconData icon;

  const _EventRow({required this.event, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: event.isCritical ? AppColors.criticalRowBg : AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: event.isCritical
              ? AppColors.primary.withOpacity(0.25)
              : AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: event.isCritical ? AppColors.primary : AppColors.onSurfaceMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Slot ${event.slotId}',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: event.isCritical ? AppColors.primary : AppColors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(event.relativeTime, style: AppTextStyles.labelSm),
                  ],
                ),
                const SizedBox(height: 4),
                Text(event.message, style: AppTextStyles.bodySm),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
