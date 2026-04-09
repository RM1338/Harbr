import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../providers/app_providers.dart';
import '../../providers/reservation_flow_provider.dart';
import '../../widgets/slot_tile.dart';
import '../../widgets/error_banner.dart';
import '../../../domain/entities/parking_slot.dart';
import '../../../core/services/reservation_integrity_service.dart';

class ReservationScreen extends ConsumerStatefulWidget {
  final String? preSelectedSlotId;
  const ReservationScreen({super.key, this.preSelectedSlotId});

  @override
  ConsumerState<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends ConsumerState<ReservationScreen> {
  late final AutoDisposeStateNotifierProvider<ReservationFlowNotifier, ReservationFlowState> _provider;

  @override
  void initState() {
    super.initState();
    _provider = reservationFlowProvider(widget.preSelectedSlotId);
  }

  Future<void> _confirm() async {
    final notifier = ref.read(_provider.notifier);
    final resId = await notifier.confirmReservation();

    if (resId != null && mounted) {
      // Schedule no-show check
      final state = ref.read(_provider);
      final user = ref.read(currentUserProvider);
      ReservationIntegrityService.scheduleNoShowCheck(
        resId: resId,
        slotId: state.selectedSlotId!,
        arrivalTime: state.arrivalTime,
        userId: user?.uid ?? '',
      );
      context.go(AppRoutes.bookings);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_provider);
    final slotsAsync = ref.watch(slotsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Reserve', style: AppTextStyles.headlineMd),
        backgroundColor: AppColors.background,
        leading: state.currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
                onPressed: () => ref.read(_provider.notifier).prevStep(),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
                onPressed: () => context.go(AppRoutes.home),
              ),
      ),
      body: Column(
        children: [
          // Step indicator
          _StepIndicator(currentStep: state.currentStep),

          if (state.error != null)
            ErrorBanner(message: state.error!),

          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _buildStep(state, slotsAsync),
            ),
          ),

          // Bottom action
          if (state.currentStep < 2)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: state.currentStep == 0 && state.selectedSlotId == null
                      ? null
                      : () => ref.read(_provider.notifier).nextStep(),
                  child: Text(state.currentStep == 0 ? 'Choose Time' : 'Review'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStep(ReservationFlowState state, AsyncValue<List<ParkingSlot>> slotsAsync) {
    switch (state.currentStep) {
      case 0:
        return _Step1SlotSelect(
          key: const ValueKey('step0'),
          slotsAsync: slotsAsync,
          selectedSlotId: state.selectedSlotId,
          onSlotSelected: (id) => ref.read(_provider.notifier).selectSlot(id),
        );
      case 1:
        return _Step2TimeSelect(
          key: const ValueKey('step1'),
          state: state,
          notifier: ref.read(_provider.notifier),
        );
      case 2:
        return _Step3Summary(
          key: const ValueKey('step2'),
          state: state,
          isSubmitting: state.isSubmitting,
          onConfirm: _confirm,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ── Step 1: Slot Selection ────────────────────────────────────────────────────
class _Step1SlotSelect extends StatelessWidget {
  final AsyncValue<List<ParkingSlot>> slotsAsync;
  final String? selectedSlotId;
  final ValueChanged<String> onSlotSelected;

  const _Step1SlotSelect({
    super.key,
    required this.slotsAsync,
    required this.selectedSlotId,
    required this.onSlotSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SELECT A SLOT', style: AppTextStyles.labelSm),
          const SizedBox(height: 8),
          Text('Available slots are highlighted in blue', style: AppTextStyles.bodySm),
          const SizedBox(height: 20),
          Expanded(
            child: slotsAsync.when(
              data: (slots) => ListView.separated(
                itemCount: slots.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final slot = slots[i];
                  final isSelected = slot.id == selectedSlotId;
                  return _SlotRowCard(
                    slot: slot,
                    isSelected: isSelected,
                    onTap: slot.isAvailable ? () => onSlotSelected(slot.id) : null,
                  );
                },
              ),
              loading: () => ListView.separated(
                itemCount: kAllSlotIds.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, __) => const _SlotRowCard(slot: null),
              ),
              error: (e, _) => ErrorBanner(message: 'Failed to load slots. $e'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotRowCard extends StatelessWidget {
  final ParkingSlot? slot;
  final bool isSelected;
  final VoidCallback? onTap;

  const _SlotRowCard({this.slot, this.isSelected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isAvailable = slot?.isAvailable ?? false;
    final statusColor = slot == null
        ? AppColors.onSurfaceDim
        : isAvailable
            ? AppColors.slotAvailable
            : AppColors.slotOccupied;
    final statusLabel = slot == null
        ? '—'
        : isAvailable
            ? 'AVAILABLE'
            : slot!.isReserved
                ? 'RESERVED'
                : 'OCCUPIED';

    return GestureDetector(
      onTap: onTap,
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
            // Slot number badge
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
                slot?.id ?? '—',
                style: AppTextStyles.slotNumber.copyWith(color: statusColor),
              ),
            ),
            const SizedBox(width: 16),
            // Label
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Parking Slot ${slot?.id ?? ''}',
                    style: AppTextStyles.bodyMd,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    statusLabel,
                    style: AppTextStyles.labelSm.copyWith(color: statusColor),
                  ),
                ],
              ),
            ),
            // Selection check
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Step 2: Time Selection ────────────────────────────────────────────────────
class _Step2TimeSelect extends StatelessWidget {
  final ReservationFlowState state;
  final ReservationFlowNotifier notifier;

  const _Step2TimeSelect({super.key, required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('hh:mm a, dd MMM');

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ARRIVAL TIME', style: AppTextStyles.labelSm),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, color: AppColors.onSurface),
                  onPressed: notifier.decrementArrivalTime,
                ),
                Text(fmt.format(state.arrivalTime), style: AppTextStyles.bodyLg),
                IconButton(
                  icon: const Icon(Icons.add, color: AppColors.onSurface),
                  onPressed: notifier.incrementArrivalTime,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text('DURATION', style: AppTextStyles.labelSm),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => notifier.setDuration(state.durationHours - 1),
                icon: const Icon(Icons.remove, color: AppColors.onSurface),
              ),
              Column(
                children: [
                  Text(
                    '${state.durationHours}',
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  Text('hours', style: AppTextStyles.bodySm),
                ],
              ),
              IconButton(
                onPressed: () => notifier.setDuration(state.durationHours + 1),
                icon: const Icon(Icons.add, color: AppColors.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('Min 1h — Max 8h', style: AppTextStyles.labelSm),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: notifier.nextStep,
              child: const Text('Review Booking'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 3: Summary ───────────────────────────────────────────────────────────
class _Step3Summary extends StatelessWidget {
  final ReservationFlowState state;
  final bool isSubmitting;
  final VoidCallback onConfirm;

  const _Step3Summary({
    super.key,
    required this.state,
    required this.isSubmitting,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('hh:mm a, dd MMM');
    final arrival = DateTime.fromMillisecondsSinceEpoch(state.arrivalEpochMs);
    final end = DateTime.fromMillisecondsSinceEpoch(state.endEpochMs);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BOOKING SUMMARY', style: AppTextStyles.labelSm),
          const SizedBox(height: 16),
          // Summary card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _SummaryRow('SLOT', state.selectedSlotId ?? '—'),
                const SizedBox(height: 16),
                _SummaryRow('ARRIVAL', fmt.format(arrival)),
                const SizedBox(height: 16),
                _SummaryRow('CHECK-OUT', fmt.format(end)),
                const SizedBox(height: 16),
                _SummaryRow('DURATION', '${state.durationHours} hours'),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(color: AppColors.border, thickness: 1),
                ),
                _SummaryRow(
                  'RATE',
                  '₹${HarbrPricing.ratePerHour.toInt()}/hr',
                  secondary: true,
                ),
                const SizedBox(height: 12),
                _SummaryRow(
                  'TOTAL',
                  '₹${state.totalCost.toInt()}',
                  highlight: true,
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: isSubmitting ? null : onConfirm,
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onSurface),
                    )
                  : const Text('Confirm Reservation'),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Cancellation available up to 30 min before arrival',
              style: AppTextStyles.labelSm,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  final bool secondary;

  const _SummaryRow(this.label, this.value, {this.highlight = false, this.secondary = false});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.labelSm),
          Text(
            value,
            style: highlight
                ? GoogleFonts.bricolageGrotesque(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  )
                : secondary
                    ? AppTextStyles.bodySm
                    : AppTextStyles.bodyMd,
          ),
        ],
      );
}

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(3, (i) {
          final isActive = i == currentStep;
          final isDone = i < currentStep;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: isDone || isActive ? AppColors.primary : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
