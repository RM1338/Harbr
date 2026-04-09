import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/app_providers.dart';
import '../../widgets/slot_map_cell.dart';
import '../../../domain/entities/parking_slot.dart';

/// Groups a list of [ParkingSlot] objects by zone.
///
/// Zone is derived from the first character of [ParkingSlot.id]
/// (e.g. "A1" → zone "A"). Returns a sorted map keyed by zone letter.
Map<String, List<ParkingSlot>> groupSlotsByZone(List<ParkingSlot> slots) {
  final Map<String, List<ParkingSlot>> grouped = {};
  for (final slot in slots) {
    if (slot.id.isEmpty) continue;
    final zone = slot.id[0].toUpperCase();
    grouped.putIfAbsent(zone, () => []).add(slot);
  }
  // Sort zones alphabetically and slots within each zone by id
  final sortedKeys = grouped.keys.toList()..sort();
  return {
    for (final key in sortedKeys)
      key: grouped[key]!..sort((a, b) => a.id.compareTo(b.id)),
  };
}

/// ParkSense Live — slot map screen.
///
/// Renders a [CustomScrollView] with zone headers and a [SliverGrid] of
/// [SlotMapCell] widgets for each zone. Consumes [slotsStreamProvider].
class SlotMapScreen extends ConsumerWidget {
  const SlotMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slotsAsync = ref.watch(slotsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: slotsAsync.when(
          loading: () => const _LoadingView(),
          error: (error, _) => _ErrorView(error: error),
          data: (slots) => _SlotMapBody(slots: slots),
        ),
      ),
    );
  }
}

// ── Loading ───────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.primary,
        strokeWidth: 2,
      ),
    );
  }
}

// ── Error ─────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final Object error;
  const _ErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 40),
            const SizedBox(height: 12),
            Text(
              'Failed to load slots',
              style: AppTextStyles.headlineSm,
            ),
            const SizedBox(height: 6),
            Text(
              error.toString(),
              style: AppTextStyles.bodySm,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _SlotMapBody extends StatelessWidget {
  final List<ParkingSlot> slots;
  const _SlotMapBody({required this.slots});

  @override
  Widget build(BuildContext context) {
    final grouped = groupSlotsByZone(slots);

    return CustomScrollView(
      slivers: [
        // Screen header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ParkSense Live',
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Real-time slot availability',
                  style: AppTextStyles.bodySm,
                ),
              ],
            ),
          ),
        ),

        // Legend
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: _Legend(),
          ),
        ),

        // Zone sections
        if (grouped.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Text('No slots available', style: AppTextStyles.bodySm),
            ),
          )
        else
          for (final entry in grouped.entries) ...[
            // Zone header
            SliverToBoxAdapter(
              child: _ZoneHeader(zone: entry.key),
            ),
            // Zone grid
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final slot = entry.value[index];
                    return SlotMapCell(
                      slot: slot,
                      onTap: () => context.push('${AppRoutes.slot}?slotId=${slot.id}'),
                    );
                  },
                  childCount: entry.value.length,
                ),
              ),
            ),
          ],

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

// ── Zone Header ───────────────────────────────────────────────────────────────

class _ZoneHeader extends StatelessWidget {
  final String zone;
  const _ZoneHeader({required this.zone});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primaryGlow,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.ghostBorder),
            ),
            alignment: Alignment.center,
            child: Text(
              zone,
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Zone $zone',
            style: AppTextStyles.headlineSm,
          ),
        ],
      ),
    );
  }
}

// ── Legend ────────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _LegendItem(color: Colors.white, label: 'Available'),
        const SizedBox(width: 16),
        _LegendItem(color: Colors.black, label: 'Occupied', bordered: true),
        const SizedBox(width: 16),
        _LegendItem(color: Colors.grey.shade300, label: 'Reserved', hatched: true),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool bordered;
  final bool hatched;

  const _LegendItem({
    required this.color,
    required this.label,
    this.bordered = false,
    this.hatched = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: bordered ? Colors.grey.shade700 : Colors.grey.shade400,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.bodySm),
      ],
    );
  }
}
