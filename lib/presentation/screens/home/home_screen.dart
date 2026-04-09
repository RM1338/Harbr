import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/router/app_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/app_providers.dart';
import '../../widgets/error_banner.dart';
import '../../../domain/entities/parking_slot.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slotsAsync = ref.watch(slotsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'harbr',
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                      letterSpacing: -0.8,
                    ),
                  ),
                  Text(
                    DateFormat('EEE, d MMM').format(DateTime.now()),
                    style: AppTextStyles.labelMd,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                FacilityInfo.fullName,
                style: AppTextStyles.headlineMd,
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                FacilityInfo.location,
                style: AppTextStyles.bodySm,
              ),
            ),

            const SizedBox(height: 24),

            // Error banner
            slotsAsync.when(
              data: (_) => const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const ErrorBanner(message: 'Unable to reach server. Showing cached data.'),
            ),

            // Slot grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PARKING SLOTS', style: AppTextStyles.labelSm),
                  const SizedBox(height: 12),
                  slotsAsync.when(
                    data: (slots) => _SlotGrid(slots: slots),
                    loading: () => const _SlotGrid(slots: null),
                    error: (_, __) => const _SlotGrid(slots: null),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Stats bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: slotsAsync.when(
                data: (slots) => _StatsBar(slots: slots),
                loading: () => const _StatsBar(slots: null),
                error: (_, __) => const _StatsBar(slots: null),
              ),
            ),

            const Spacer(),

            // Reserve CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => context.go(AppRoutes.reservation),
                  child: const Text('Reserve a Slot'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotGrid extends StatefulWidget {
  final List<ParkingSlot>? slots;
  const _SlotGrid({this.slots});

  @override
  State<_SlotGrid> createState() => _SlotGridState();
}

class _SlotGridState extends State<_SlotGrid> {
  String? _selectedSlotId;

  @override
  Widget build(BuildContext context) {
    final List<ParkingSlot?> displaySlots = widget.slots ?? List<ParkingSlot?>.generate(kAllSlotIds.length, (i) => null);

    return Column(
      children: List.generate(displaySlots.length, (index) {
        final ParkingSlot? slot = widget.slots != null ? widget.slots![index] : null;
        final isAvailable = slot?.isAvailable ?? false;
        final isSelected = slot?.id == _selectedSlotId;
        final statusColor = slot == null
            ? AppColors.onSurfaceDim
            : isAvailable
                ? AppColors.slotAvailable
                : AppColors.slotOccupied;
        final statusLabel = slot == null
            ? '—'
            : isAvailable
                ? 'AVAILABLE'
                : slot.isReserved
                    ? 'RESERVED'
                    : 'OCCUPIED';

        return Padding(
          padding: EdgeInsets.only(bottom: index < displaySlots.length - 1 ? 10 : 0),
          child: GestureDetector(
            onTap: slot?.isAvailable == true
                ? () {
                    setState(() => _selectedSlotId = slot!.id);
                    context.go('${AppRoutes.reservation}?slotId=${slot!.id}');
                  }
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.12)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : isAvailable
                          ? AppColors.slotAvailable.withOpacity(0.35)
                          : AppColors.border,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      slot?.id ?? kAllSlotIds[index],
                      style: AppTextStyles.slotNumber.copyWith(color: statusColor),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Parking Slot ${slot?.id ?? kAllSlotIds[index]}',
                            style: AppTextStyles.bodyMd),
                        const SizedBox(height: 2),
                        Text(statusLabel,
                            style: AppTextStyles.labelSm.copyWith(color: statusColor)),
                      ],
                    ),
                  ),
                  if (isAvailable)
                    const Icon(Icons.chevron_right, color: AppColors.onSurfaceDim, size: 20),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _StatsBar extends StatelessWidget {
  final List<ParkingSlot>? slots;
  const _StatsBar({this.slots});

  @override
  Widget build(BuildContext context) {
    final total     = slots?.length ?? kAllSlotIds.length;
    final available = slots?.where((s) => s.isAvailable).length ?? 0;
    final occupied  = slots?.where((s) => s.isOccupied).length ?? 0;
    final reserved  = slots?.where((s) => s.isReserved).length ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(label: 'TOTAL',     value: '$total',     color: AppColors.onSurface),
          _Divider(),
          _StatItem(label: 'FREE',      value: '$available', color: AppColors.slotAvailable),
          _Divider(),
          _StatItem(label: 'OCCUPIED',  value: '$occupied',  color: slots == null ? AppColors.onSurfaceDim : AppColors.slotOccupied),
          _Divider(),
          _StatItem(label: 'RESERVED',  value: '$reserved',  color: slots == null ? AppColors.onSurfaceDim : AppColors.warning),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 32,
        color: AppColors.border,
      );
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.labelSm),
      ],
    );
  }
}
