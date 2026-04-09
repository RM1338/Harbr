import 'package:equatable/equatable.dart';
import '../../core/constants/app_constants.dart';

class ParkingSlot extends Equatable {
  final String id;
  final String status;
  final String? reservedBy;
  final int? until;
  final String? vehicleType;       // 'ev' | 'ice' | null
  final int? lastSensorReading;    // Unix ms
  final String? syncStatus;        // 'synced' | 'stale'

  const ParkingSlot({
    required this.id,
    required this.status,
    this.reservedBy,
    this.until,
    this.vehicleType,
    this.lastSensorReading,
    this.syncStatus,
  });

  bool get isAvailable => status == SlotStatus.available;
  bool get isOccupied => status == SlotStatus.occupied;
  bool get isReserved => status == SlotStatus.reserved;

  ParkingSlot copyWith({
    String? id,
    String? status,
    String? reservedBy,
    int? until,
    String? vehicleType,
    int? lastSensorReading,
    String? syncStatus,
  }) {
    return ParkingSlot(
      id: id ?? this.id,
      status: status ?? this.status,
      reservedBy: reservedBy ?? this.reservedBy,
      until: until ?? this.until,
      vehicleType: vehicleType ?? this.vehicleType,
      lastSensorReading: lastSensorReading ?? this.lastSensorReading,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  List<Object?> get props => [id, status, reservedBy, until, vehicleType, lastSensorReading, syncStatus];
}
