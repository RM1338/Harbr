import 'package:equatable/equatable.dart';

class GateEvent extends Equatable {
  final String id;
  final String type;
  final String message;
  final int timestamp; // Unix epoch milliseconds

  const GateEvent({
    required this.id,
    required this.type,
    required this.message,
    required this.timestamp,
  });

  GateEvent copyWith({
    String? id,
    String? type,
    String? message,
    int? timestamp,
  }) {
    return GateEvent(
      id: id ?? this.id,
      type: type ?? this.type,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  List<Object?> get props => [id, type, message, timestamp];
}
