import 'package:equatable/equatable.dart';

class ParkingEvent extends Equatable {
  final String id;
  final String type;
  final String slotId;
  final String message;
  final int timestamp; // Unix epoch milliseconds
  final String severity;

  const ParkingEvent({
    required this.id,
    required this.type,
    required this.slotId,
    required this.message,
    required this.timestamp,
    required this.severity,
  });

  bool get isCritical => severity == 'critical';

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);

  String get relativeTime {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  List<Object?> get props => [id, type, slotId, message, timestamp, severity];
}
