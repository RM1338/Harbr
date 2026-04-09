import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/app_providers.dart';
import '../../../data/datasources/firebase_slot_datasource.dart';
import '../../../data/datasources/firebase_gate_datasource.dart';
import '../../../domain/entities/parking_slot.dart';

/// Slot detail screen — displays full metadata for a single parking slot
/// and allows the user to reserve it when available.
///
/// Accepts a [slotId] query parameter and looks up the slot from
/// [slotsStreamProvider].
class SlotDetailScreen extends ConsumerStatefulWidget {
  final String slotId;

  const SlotDetailScreen({super.key, required this.slotId});

  @override
  ConsumerState<SlotDetailScreen> createState() => _SlotDetailScreenState();
}

class _SlotDetailScreenState extends ConsumerState<SlotDetailScreen> {
  bool _isReserving = false;

  /// Zone is the first character of the slot ID (e.g. "A" from "A1")
  String get _zone => widget.slotId.isNotEmpty ? widget.slotId[0].toUpperCase() : '—';

  /// Row is the second character of the slot ID (e.g. "1" from "A1")
  String get _row => widget.slotId.length > 1 ? widget.slotId.substring(1) : '—';

  Future<void> _onReserveTap(ParkingSlot slot) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isReserving = true);

    try {
      // Task 3.4 — Race condition check: re-read slot status at write time
      final slotDs = FirebaseSlotDataSource();
      final currentStatus = await slotDs.getSlotStatus(widget.slotId);

      if (currentStatus != SlotStatus.available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Slot ${widget.slotId} is no longer available.',
                style: AppTextStyles.bodyMd,
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Task 3.3 — Create reservation
      final reservationDs = ref.read(firebaseReservationDSProvider);
      final now = DateTime.now().millisecondsSinceEpoch;

      final resId = await reservationDs.createReservation(
        userId: user.uid,
        slotId: widget.slotId,
        arrivalTime: now,
        durationHours: 1,
      );

      // Task 3.3 — Write to /gate/reservation
      final gateDs = FirebaseGateDataSource();
      await gateDs.writeGateReservation(
        slotId: widget.slotId,
        userId: user.uid,
        timestamp: now,
      );

      // Update slot status to reserved
      await slotDs.updateSlot(
        slotId: widget.slotId,
        status: SlotStatus.reserved,
        reservedBy: user.uid,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Slot ${widget.slotId} reserved successfully! (ID: $resId)',
              style: AppTextStyles.bodyMd,
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Reservation failed: $e',
              style: AppTextStyles.bodyMd,
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isReserving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slotsAsync = ref.watch(slotsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Slot ${widget.slotId}', style: AppTextStyles.headlineMd),
        elevation: 0,
      ),
      body: slotsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 40),
                const SizedBox(height: 12),
                Text('Failed to load slot', style: AppTextStyles.headlineSm),
                const SizedBox(height: 6),
                Text(error.toString(), style: AppTextStyles.bodySm, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
        data: (slots) {
          final slot = slots.where((s) => s.id == widget.slotId).firstOrNull;
          if (slot == null) {
            return Center(
              child: Text('Slot ${widget.slotId} not found', style: AppTextStyles.bodySm),
            );
          }
          return _SlotDetailBody(
            slot: slot,
            zone: _zone,
            row: _row,
            isReserving: _isReserving,
            onReserveTap: () => _onReserveTap(slot),
          );
        },
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _SlotDetailBody extends StatelessWidget {
  final ParkingSlot slot;
  final String zone;
  final String row;
  final bool isReserving;
  final VoidCallback onReserveTap;

  const _SlotDetailBody({
    required this.slot,
    required this.zone,
    required this.row,
    required this.isReserving,
    required this.onReserveTap,
  });

  Color get _statusColor {
    if (slot.isAvailable) return AppColors.slotAvailable;
    if (slot.isReserved) return AppColors.slotReserved;
    return AppColors.slotOccupied;
  }

  String get _statusLabel {
    if (slot.isAvailable) return 'AVAILABLE';
    if (slot.isReserved) return 'RESERVED';
    return 'OCCUPIED';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Slot hero badge
            _SlotHeroBadge(slotId: slot.id, statusColor: _statusColor, statusLabel: _statusLabel),

            const SizedBox(height: 28),

            // Metadata section
            Text('SLOT DETAILS', style: AppTextStyles.labelSm),
            const SizedBox(height: 12),
            _MetadataCard(slot: slot, zone: zone, row: row),

            const SizedBox(height: 28),

            // Sensor section
            Text('SENSOR DATA', style: AppTextStyles.labelSm),
            const SizedBox(height: 12),
            _SensorCard(slot: slot),

            const SizedBox(height: 32),

            // Task 3.2 — Reserve button: visible and enabled only when slot.isAvailable
            if (slot.isAvailable)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isReserving ? null : onReserveTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isReserving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onSurface,
                          ),
                        )
                      : Text('Reserve Slot', style: AppTextStyles.buttonText),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Slot Hero Badge ───────────────────────────────────────────────────────────

class _SlotHeroBadge extends StatelessWidget {
  final String slotId;
  final Color statusColor;
  final String statusLabel;

  const _SlotHeroBadge({
    required this.slotId,
    required this.statusColor,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withOpacity(0.4), width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(
            slotId,
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: statusColor,
            ),
          ),
        ),
        const SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Parking Slot $slotId', style: AppTextStyles.headlineSm),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Text(
                statusLabel,
                style: AppTextStyles.labelSm.copyWith(color: statusColor),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Metadata Card ─────────────────────────────────────────────────────────────

class _MetadataCard extends StatelessWidget {
  final ParkingSlot slot;
  final String zone;
  final String row;

  const _MetadataCard({required this.slot, required this.zone, required this.row});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _DetailRow(label: 'SLOT ID', value: slot.id),
          const _RowDivider(),
          _DetailRow(label: 'ZONE', value: zone),
          const _RowDivider(),
          _DetailRow(label: 'ROW', value: row),
        ],
      ),
    );
  }
}

// ── Sensor Card ───────────────────────────────────────────────────────────────

class _SensorCard extends StatelessWidget {
  final ParkingSlot slot;

  const _SensorCard({required this.slot});

  String _formatSensorReading(int? unixMs) {
    if (unixMs == null) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(unixMs);
    return DateFormat('dd MMM yyyy, hh:mm:ss a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final syncColor = slot.syncStatus == 'synced'
        ? AppColors.success
        : slot.syncStatus == 'stale'
            ? AppColors.warning
            : AppColors.onSurfaceDim;

    final syncLabel = slot.syncStatus?.toUpperCase() ?? '—';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _DetailRow(
            label: 'LAST SENSOR READING',
            value: _formatSensorReading(slot.lastSensorReading),
          ),
          const _RowDivider(),
          _DetailRow(
            label: 'SYNC STATUS',
            value: syncLabel,
            valueColor: syncColor,
          ),
        ],
      ),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.labelSm),
        Text(
          value,
          style: AppTextStyles.bodyMd.copyWith(
            color: valueColor ?? AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Divider(color: AppColors.border, thickness: 1, height: 1),
    );
  }
}
