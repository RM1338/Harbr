import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  final String uid;
  final String displayName;
  final String email;
  final String vehicleNumber;

  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.vehicleNumber,
  });

  UserProfile copyWith({
    String? uid,
    String? displayName,
    String? email,
    String? vehicleNumber,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
    );
  }

  @override
  List<Object?> get props => [uid, displayName, email, vehicleNumber];
}
