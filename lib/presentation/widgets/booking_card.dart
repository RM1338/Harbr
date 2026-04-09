import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/datasources/firebase_gate_datasource.dart';
import '../../domain/entities/reservation.dart';

class BookingCard extends StatefulWidget {
  final Reservation reservation;

  const BookingCard({super.key, required this.reservation});

  @override
  State<BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<BookingCard> {
  late Timer _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = _computeRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _remaining = _computeRemaining();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Duration _computeRemaining() {
    final end = DateTime.fromMillisecondsSinceEpoch(widget.reservation.endTime);
    final diff = end.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  String _formatCountdown(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _openGate(BuildContext context) async {
    try {
      await FirebaseGateDataSource().writeOpenCommand(true);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gate open command sent')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open gate: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final slotId = widget.reservation.slotId;
    final zone = slotId.isNotEmpty ? slotId[0] : '?';
    final isExpired = _remaining == Duration.zero;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.ghostBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: slot badge + zone + status
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    slotId,
                    style: AppTextStyles.slotNumber.copyWith(
                      color: AppColors.primary,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Zone $zone', style: AppTextStyles.headlineSm),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.slotAvailable,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Active',
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.slotAvailable,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Countdown
          Row(
            children: [
              Text('TIME REMAINING', style: AppTextStyles.labelSm),
              const Spacer(),
              Text(
                _formatCountdown(_remaining),
                style: AppTextStyles.headlineMd.copyWith(
                  color: isExpired ? AppColors.error : AppColors.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Open Gate button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openGate(context),
              icon: const Icon(Icons.sensor_door_outlined, size: 18),
              label: const Text('Open Gate'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                textStyle: AppTextStyles.buttonText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
