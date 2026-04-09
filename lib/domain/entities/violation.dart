import 'package:equatable/equatable.dart';

/// Represents a parking violation detected by the CV pipeline.
/// Written by the Python backend to /slots/{slotId}/violation.
class Violation extends Equatable {
  final String slotId;
  final String type; // 'ice_in_ev_slot' | 'ev_no_cable'
  final int timestamp; // Unix ms

  const Violation({
    required this.slotId,
    required this.type,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [slotId, type, timestamp];
}
