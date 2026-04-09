/// Slot status constants matching Stitch design
class SlotStatus {
  static const String available = 'available';
  static const String occupied = 'occupied';
  static const String reserved = 'reserved';
}

/// Reservation status constants
class ReservationStatus {
  static const String active = 'active';
  static const String cancelled = 'cancelled';
  static const String completed = 'completed';
  static const String noShow = 'no_show';
}

/// Event severity constants
class EventSeverity {
  static const String critical = 'critical';
  static const String warning = 'warning';
  static const String info = 'info';
}

/// Event type constants
class EventType {
  static const String violation = 'violation';
  static const String noShow = 'no_show';
  static const String reservation = 'reservation';
  static const String sensor = 'sensor';
  static const String auth = 'auth';
}

/// Hive box names
class HiveBoxes {
  static const String reservationsCache = 'reservations_cache';
  static const String authCache = 'auth_cache';
  static const String settings = 'settings';
  static const String userProfile = 'user_profile';
}

/// Hive settings keys
class SettingsKeys {
  static const String notificationsEnabled = 'notifications_enabled';
  static const String lastUserId = 'last_user_id';
}

/// Pricing
class HarbrPricing {
  /// ₹20 per hour
  static const double ratePerHour = 20.0;
}

/// Facility / location constants — change these to match your deployment
class FacilityInfo {
  static const String name     = 'Harbour Gateway';
  static const String terminal = 'Terminal A';
  static const String city     = 'Mumbai';
  static const String state    = 'Maharashtra';
  static const String appVersion = '1.0.0';

  static String get fullName    => '$name · $terminal';
  static String get location    => '$city, $state';
  static String get footerLabel => 'harbr v$appVersion · $name, $city';
}

/// 4 parking slot IDs — must match SLOT_ROIS keys in cv_pipeline/main.py
const List<String> kAllSlotIds = [
  'A1', 'A2', 'A3', 'A4',
];
