import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/app_providers.dart';
import '../../widgets/booking_card.dart';
import '../../widgets/error_banner.dart';
import '../../../domain/entities/reservation.dart';
import '../../../data/datasources/firebase_reservation_datasource.dart';
import '../../../data/datasources/firebase_slot_datasource.dart';

class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservationsAsync = ref.watch(userReservationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('My Bookings', style: AppTextStyles.headlineMd),
        backgroundColor: AppColors.background,
        automaticallyImplyLeading: false,
      ),
      body: reservationsAsync.when(
        data: (reservations) {
          final active = reservations.where((r) => r.isActive).firstOrNull;
          final past = reservations.where((r) => r.isPast).toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            children: [
              // Active booking section
              Text('ACTIVE BOOKING', style: AppTextStyles.labelSm),
              const SizedBox(height: 12),
              if (active != null)
                BookingCard(reservation: active)
              else
                _NoActiveBooking(),
              const SizedBox(height: 32),
              // Past bookings section
              if (past.isNotEmpty) ...[
                Text('PAST', style: AppTextStyles.labelSm),
                const SizedBox(height: 12),
                ...past.map<Widget>((r) => _BookingRow(reservation: r, isActive: false, ref: ref)),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => const ErrorBanner(message: 'Failed to load bookings. Check connection.'),
      ),
    );
  }
}

class _NoActiveBooking extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_parking_outlined,
              size: 40, color: AppColors.onSurfaceDim),
          const SizedBox(height: 12),
          Text('No active booking', style: AppTextStyles.bodyLg),
          const SizedBox(height: 4),
          Text('Reserve a slot to see it here',
              style: AppTextStyles.bodySm),
        ],
      ),
    );
  }
}

class _BookingRow extends StatelessWidget {
  final Reservation reservation;
  final bool isActive;
  final WidgetRef ref;

  const _BookingRow({
    required this.reservation,
    required this.isActive,
    required this.ref,
  });

  Future<void> _cancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Cancel Booking', style: AppTextStyles.headlineSm),
        content: Text(
          'Cancel reservation for slot ${reservation.slotId}? This cannot be undone.',
          style: AppTextStyles.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep', style: TextStyle(color: AppColors.onSurfaceMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Booking', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final resDS = FirebaseReservationDataSource();
      final slotDS = FirebaseSlotDataSource();
      await resDS.updateReservationStatus(reservation.id, ReservationStatus.cancelled);
      await slotDS.updateSlot(
        slotId: reservation.slotId,
        status: SlotStatus.available,
        reservedBy: null,
        until: null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM · HH:mm');
    final arrival = DateTime.fromMillisecondsSinceEpoch(reservation.arrivalTime);
    final end = DateTime.fromMillisecondsSinceEpoch(reservation.endTime);

    Color statusColor;
    String statusLabel;
    switch (reservation.status) {
      case ReservationStatus.active:
        statusColor = AppColors.slotAvailable;
        statusLabel = 'Active';
        break;
      case ReservationStatus.cancelled:
        statusColor = AppColors.error;
        statusLabel = 'Cancelled';
        break;
      case ReservationStatus.noShow:
        statusColor = AppColors.warning;
        statusLabel = 'No-show';
        break;
      default:
        statusColor = AppColors.onSurfaceDim;
        statusLabel = 'Completed';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Slot badge
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primary.withOpacity(0.12)
                  : AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                reservation.slotId,
                style: AppTextStyles.slotNumber.copyWith(
                  color: isActive ? AppColors.primary : AppColors.onSurface,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${fmt.format(arrival)} – ${DateFormat('HH:mm').format(end)}',
                  style: AppTextStyles.bodyMd,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(statusLabel, style: AppTextStyles.bodySm.copyWith(color: statusColor)),
                    const SizedBox(width: 12),
                    Text('₹${reservation.totalCost.toInt()}', style: AppTextStyles.bodySm),
                  ],
                ),
              ],
            ),
          ),
          if (isActive && reservation.status == ReservationStatus.active)
            TextButton(
              onPressed: () => _cancel(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
              ),
              child: Text('Cancel', style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
            ),
        ],
      ),
    );
  }
}
