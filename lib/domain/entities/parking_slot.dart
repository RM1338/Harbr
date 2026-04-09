import 'package:equatable/equatable.dart';
import '../../core/constants/app_constants.dart';

class ParkingSlot extends Equatable {
  final String id;
  final String status;
  final String? reservedBy;
  final int? until;

  const ParkingSlot({
    required this.id,
    required this.status,
    this.reservedBy,
    this.until,
  });

  bool get isAvailable => status == SlotStatus.available;
  bool get isOccupied => status == SlotStatus.occupied;
  bool get isReserved => status == SlotStatus.reserved;

  ParkingSlot copyWith({
    String? id,
    String? status,
    String? reservedBy,
    int? until,
  }) {
    return ParkingSlot(
      id: id ?? this.id,
      status: status ?? this.status,
      reservedBy: reservedBy ?? this.reservedBy,
      until: until ?? this.until,
    );
  }

  @override
  List<Object?> get props => [id, status, reservedBy, until];
}
