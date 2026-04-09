import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/gate_event.dart';

/// Terminal-style log row for a single [GateEvent].
/// Dark background with monospace font and color-coded event type badge.
class GateLogEntry extends StatelessWidget {
  final GateEvent event;

  const GateLogEntry({super.key, required this.event});

  // ── Helpers ──────────────────────────────────────────────────

  String get _formattedTime {
    final dt = DateTime.fromMillisecondsSinceEpoch(event.timestamp);
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Color get _typeColor {
    switch (event.type.toLowerCase()) {
      case 'open':
      case 'ready':
      case 'entry':
        return AppColors.success; // green
      case 'warning':
      case 'detected':
        return AppColors.warning; // amber
      case 'error':
      case 'closed':
      case 'denied':
        return AppColors.error; // red
      default:
        return AppColors.primary; // blue fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    final mono = GoogleFonts.robotoMono(
      fontSize: 11,
      fontWeight: FontWeight.w400,
      color: AppColors.onSurfaceMuted,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp
          Text(_formattedTime, style: mono),
          const SizedBox(width: 10),

          // Type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _typeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: _typeColor.withOpacity(0.35), width: 0.5),
            ),
            child: Text(
              event.type.toUpperCase(),
              style: GoogleFonts.robotoMono(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: _typeColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Message
          Expanded(
            child: Text(
              event.message,
              style: mono.copyWith(color: AppColors.onSurface),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}
