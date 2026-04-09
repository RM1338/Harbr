import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/firebase_slot_datasource.dart';
import '../../data/datasources/firebase_reservation_datasource.dart';
import '../../data/datasources/firebase_auth_datasource.dart';
import '../../core/constants/app_constants.dart';

// ── 3-Step Reservation Flow State ────────────────────────────────────────────

class ReservationFlowState {
  final int currentStep; // 0, 1, 2
  final String? selectedSlotId;
  final DateTime arrivalTime;
  final int durationHours;
  final bool isSubmitting;
  final String? error;

  const ReservationFlowState({
    this.currentStep = 0,
    this.selectedSlotId,
    DateTime? arrivalTime,
    this.durationHours = 2,
    this.isSubmitting = false,
    this.error,
  }) : arrivalTime = arrivalTime ?? const _DefaultTime();

  // Computed
  double get totalCost => durationHours * HarbrPricing.ratePerHour;
  int get arrivalEpochMs => arrivalTime.millisecondsSinceEpoch;
  int get endEpochMs => arrivalEpochMs + (durationHours * 60 * 60 * 1000);

  ReservationFlowState copyWith({
    int? currentStep,
    String? selectedSlotId,
    DateTime? arrivalTime,
    int? durationHours,
    bool? isSubmitting,
    String? error,
  }) {
    return ReservationFlowState(
      currentStep: currentStep ?? this.currentStep,
      selectedSlotId: selectedSlotId ?? this.selectedSlotId,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      durationHours: durationHours ?? this.durationHours,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
    );
  }
}

// hack to allow const initializer for DateTime
class _DefaultTime implements DateTime {
  const _DefaultTime();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    // dart doesn't allow const DateTime — this class is never used at runtime
    return super.noSuchMethod(invocation);
  }
}

class ReservationFlowNotifier extends StateNotifier<ReservationFlowState> {
  final FirebaseSlotDataSource _slotDS;
  final FirebaseReservationDataSource _reservationDS;
  final String _userId;

  ReservationFlowNotifier({
    required FirebaseSlotDataSource slotDS,
    required FirebaseReservationDataSource reservationDS,
    required String userId,
    String? preSelectedSlotId,
  })  : _slotDS = slotDS,
        _reservationDS = reservationDS,
        _userId = userId,
        super(ReservationFlowState(
          selectedSlotId: preSelectedSlotId,
          currentStep: preSelectedSlotId != null ? 1 : 0,
          arrivalTime: DateTime.now().add(const Duration(minutes: 30)),
        ));

  void selectSlot(String slotId) {
    state = state.copyWith(selectedSlotId: slotId);
  }

  void nextStep() {
    if (state.currentStep < 2) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    }
  }

  void prevStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1, error: null);
    }
  }

  void incrementArrivalTime() {
    state = state.copyWith(
      arrivalTime: state.arrivalTime.add(const Duration(minutes: 30)),
    );
  }

  void decrementArrivalTime() {
    final newTime = state.arrivalTime.subtract(const Duration(minutes: 30));
    if (newTime.isAfter(DateTime.now())) {
      state = state.copyWith(arrivalTime: newTime);
    }
  }

  void setDuration(int hours) {
    if (hours >= 1 && hours <= 8) {
      state = state.copyWith(durationHours: hours);
    }
  }

  Future<String?> confirmReservation() async {
    if (state.selectedSlotId == null) return null;

    state = state.copyWith(isSubmitting: true, error: null);

    try {
      final slotId = state.selectedSlotId!;

      // Verify slot is still available
      final currentStatus = await _slotDS.getSlotStatus(slotId);
      if (currentStatus != SlotStatus.available) {
        state = state.copyWith(
          isSubmitting: false,
          error: 'Slot $slotId is no longer available',
        );
        return null;
      }

      // Create reservation
      final resId = await _reservationDS.createReservation(
        userId: _userId,
        slotId: slotId,
        arrivalTime: state.arrivalEpochMs,
        durationHours: state.durationHours,
      );

      // Update slot status
      await _slotDS.updateSlot(
        slotId: slotId,
        status: SlotStatus.reserved,
        reservedBy: _userId,
        until: state.endEpochMs,
      );

      state = state.copyWith(isSubmitting: false);
      return resId;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: 'Failed to confirm reservation. Please try again.',
      );
      return null;
    }
  }
}

// Provider factory — created per reservation screen instance
final reservationFlowProvider = StateNotifierProvider.autoDispose
    .family<ReservationFlowNotifier, ReservationFlowState, String?>(
  (ref, preSelectedSlotId) {
    final slotDS = ref.watch(
      Provider((ref) => FirebaseSlotDataSource()),
    );
    final reservationDS = ref.watch(
      Provider((ref) => FirebaseReservationDataSource()),
    );

    // Inline import workaround
    final user = FirebaseAuthDataSource().currentUser;

    return ReservationFlowNotifier(
      slotDS: slotDS,
      reservationDS: reservationDS,
      userId: user?.uid ?? '',
      preSelectedSlotId: preSelectedSlotId,
    );
  },
);
