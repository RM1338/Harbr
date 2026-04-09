import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/parking_slot.dart';

/// Painter that draws diagonal hatching lines over a light grey background.
/// Used to represent 'reserved' slots in the slot map grid.
class _HatchPainter extends CustomPainter {
  const _HatchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const spacing = 8.0;
    final diagonal = size.width + size.height;

    for (double i = -diagonal; i < diagonal; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Color-coded grid cell for the ParkSense Live slot map.
///
/// - available  → white background
/// - occupied   → black background
/// - reserved   → light grey background with diagonal hatching
class SlotMapCell extends StatelessWidget {
  final ParkingSlot slot;
  final VoidCallback? onTap;

  const SlotMapCell({
    super.key,
    required this.slot,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1,
        child: _buildCell(),
      ),
    );
  }

  Widget _buildCell() {
    switch (slot.status) {
      case SlotStatus.available:
        return _buildAvailableCell();
      case SlotStatus.occupied:
        return _buildOccupiedCell();
      case SlotStatus.reserved:
        return _buildReservedCell();
      default:
        return _buildAvailableCell();
    }
  }

  Widget _buildAvailableCell() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Text(
          slot.id,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildOccupiedCell() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.grey.shade800),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Text(
          slot.id,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildReservedCell() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          children: [
            // Hatched pattern layer
            Positioned.fill(
              child: CustomPaint(
                painter: const _HatchPainter(),
              ),
            ),
            // Slot ID label on top
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  slot.id,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
