import 'package:equatable/equatable.dart';
import '../../core/constants/app_constants.dart';

class Reservation extends Equatable {
  final String id;
  final String userId;
  final String slotId;
  final int arrivalTime; // Unix epoch milliseconds
  final int durationHours;
  final String status;
  final int createdAt; // Unix epoch milliseconds

  const Reservation({
    required this.id,
    required this.userId,
    required this.slotId,
    required this.arrivalTime,
    required this.durationHours,
    required this.status,
    required this.createdAt,
  });

  /// End time in milliseconds
  int get endTime => arrivalTime + (durationHours * 60 * 60 * 1000);

  bool get isActive =>
      status == ReservationStatus.active &&
      DateTime.fromMillisecondsSinceEpoch(endTime).isAfter(DateTime.now());

  bool get isPast =>
      status == ReservationStatus.cancelled ||
      status == ReservationStatus.completed ||
      status == ReservationStatus.noShow ||
      (status == ReservationStatus.active &&
          DateTime.fromMillisecondsSinceEpoch(endTime).isBefore(DateTime.now()));

  double get totalCost => durationHours * HarbrPricing.ratePerHour;

  Reservation copyWith({
    String? id,
    String? userId,
    String? slotId,
    int? arrivalTime,
    int? durationHours,
    String? status,
    int? createdAt,
  }) {
    return Reservation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      slotId: slotId ?? this.slotId,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      durationHours: durationHours ?? this.durationHours,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, userId, slotId, arrivalTime, durationHours, status, createdAt];
}
