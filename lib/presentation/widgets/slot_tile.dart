import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/entities/parking_slot.dart';
import '../../core/constants/app_constants.dart';

/// SlotTile widget — the core UI mechanic of Harbr
/// Available: #3B82F6, Occupied: #EF4444, Reserved: #8B5CF6
class SlotTile extends StatelessWidget {
  final ParkingSlot? slot; // null = shimmer loading state
  final bool isSelected;
  final VoidCallback? onTap;

  const SlotTile({
    super.key,
    this.slot,
    this.isSelected = false,
    this.onTap,
  });

  Color get _statusColor {
    if (slot == null) return AppColors.surface;
    switch (slot!.status) {
      case SlotStatus.available:
        return AppColors.slotAvailable;
      case SlotStatus.occupied:
        return AppColors.slotOccupied;
      case SlotStatus.reserved:
        return AppColors.slotReserved;
      default:
        return AppColors.onSurfaceDim;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Shimmer loading state
    if (slot == null) {
      return Shimmer.fromColors(
        baseColor: AppColors.surface,
        highlightColor: AppColors.surfaceElevated,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      );
    }

    final canTap = slot!.isAvailable && onTap != null;

    return GestureDetector(
      onTap: canTap ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _statusColor.withOpacity(slot!.isAvailable ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(6),
          border: isSelected
              ? Border.all(color: Colors.white.withOpacity(0.8), width: 1)
              : Border.all(color: _statusColor.withOpacity(0.4), width: 1),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.12),
                    blurRadius: 8,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              slot!.id,
              style: AppTextStyles.slotNumber,
            ),
          ],
        ),
      ),
    );
  }
}
