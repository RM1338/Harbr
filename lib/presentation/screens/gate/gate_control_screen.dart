import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/datasources/firebase_gate_datasource.dart';
import '../../providers/gate_providers.dart';
import '../../widgets/gate_log_entry.dart';

class GateControlScreen extends ConsumerStatefulWidget {
  const GateControlScreen({super.key});

  @override
  ConsumerState<GateControlScreen> createState() => _GateControlScreenState();
}

class _GateControlScreenState extends ConsumerState<GateControlScreen> {
  bool _dialogShowing = false;

  @override
  Widget build(BuildContext context) {
    final gateStatusAsync = ref.watch(gateStatusProvider);
    final gateEventsAsync = ref.watch(gateEventsProvider);

    // Listen for entry detection and show confirmation dialog
    ref.listen<AsyncValue<bool>>(entryDetectedProvider, (prev, next) {
      final detected = next.valueOrNull ?? false;
      if (detected && !_dialogShowing) {
        _dialogShowing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showEntryDialog(context);
        });
      }
    });

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
                    'Gate Control',
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                      letterSpacing: -0.8,
                    ),
                  ),
                  // Gate status badge
                  gateStatusAsync.when(
                    data: (status) => _GateStatusBadge(status: status),
                    loading: () => const _GateStatusBadge(status: null),
                    error: (_, __) => const _GateStatusBadge(status: null),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                FacilityInfo.fullName,
                style: AppTextStyles.bodySm,
              ),
            ),

            const SizedBox(height: 20),

            // Event log header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text('EVENT LOG', style: AppTextStyles.labelSm),
            ),
            const SizedBox(height: 8),

            // Scrollable event log
            Expanded(
              child: gateEventsAsync.when(
                data: (events) {
                  if (events.isEmpty) {
                    return Center(
                      child: Text(
                        'No events yet',
                        style: AppTextStyles.bodySm,
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: events.length,
                    itemBuilder: (context, index) =>
                        GateLogEntry(event: events[index]),
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 1.5,
                  ),
                ),
                error: (e, _) => Center(
                  child: Text(
                    'Failed to load events',
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.error),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEntryDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text(
          'Vehicle Detected',
          style: AppTextStyles.headlineSm,
        ),
        content: Text(
          'A vehicle has been detected at the gate. Confirm entry to open the gate.',
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceMuted),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _dialogShowing = false;
            },
            child: Text(
              'Dismiss',
              style: AppTextStyles.buttonText.copyWith(
                color: AppColors.onSurfaceMuted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              _dialogShowing = false;
              await FirebaseGateDataSource().writeOpenCommand(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text('Confirm Entry & Open Gate'),
          ),
        ],
      ),
    ).then((_) {
      _dialogShowing = false;
    });
  }
}

// ── Gate Status Badge ─────────────────────────────────────────────────────────

class _GateStatusBadge extends StatelessWidget {
  final String? status;
  const _GateStatusBadge({this.status});

  Color get _color {
    switch (status) {
      case 'ready':
        return AppColors.success;
      case 'open':
        return AppColors.primary;
      case 'closed':
        return AppColors.error;
      default:
        return AppColors.onSurfaceDim;
    }
  }

  String get _label => status?.toUpperCase() ?? '—';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            _label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _color,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
