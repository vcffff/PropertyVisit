import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/viewing_repository.dart';
import '../../../core/network/api_client.dart';
import '../domain/viewing.dart';

class SlotInfo extends Equatable {
  const SlotInfo({
    required this.startLocal,
    required this.startUtcMs,
    required this.available,
  });

  final DateTime startLocal;

  /// UTC epoch-ms начала слота — как в API бэкенда.
  final int startUtcMs;
  final bool available;

  @override
  List<Object?> get props => [startLocal, startUtcMs, available];
}

enum BookingStatus { loading, ready, submitting, success, failure }

class BookingState extends Equatable {
  const BookingState({
    required this.status,
    this.day,
    this.slots = const [],
    this.selectedUtcMs,
    this.booked,
    this.error,
  });

  const BookingState.loading() : this(status: BookingStatus.loading);

  final BookingStatus status;
  final DateTime? day;
  final List<SlotInfo> slots;
  final int? selectedUtcMs;
  final Viewing? booked;
  final String? error;

  BookingState copyWith({
    BookingStatus? status,
    DateTime? day,
    List<SlotInfo>? slots,
    int? selectedUtcMs,
    Viewing? booked,
    String? error,
    bool clearSelection = false,
    bool clearBooked = false,
  }) => BookingState(
    status: status ?? this.status,
    day: day ?? this.day,
    slots: slots ?? this.slots,
    selectedUtcMs: clearSelection
        ? null
        : (selectedUtcMs ?? this.selectedUtcMs),
    booked: clearBooked ? null : (booked ?? this.booked),
    error: error,
  );

  @override
  List<Object?> get props => [status, day, slots, selectedUtcMs, booked, error];
}

class BookingCubit extends Cubit<BookingState> {
  BookingCubit(this._repo, {required this.propertyId})
    : super(const BookingState.loading());

  final ViewingRepository _repo;
  final String propertyId;
  int _dayRequest = 0;

  Future<void> loadDay(DateTime day) async {
    if (isClosed || state.status == BookingStatus.submitting) return;
    final request = ++_dayRequest;
    emit(
      BookingState(
        status: state.status == BookingStatus.success
            ? BookingStatus.success
            : BookingStatus.loading,
        day: day,
      ),
    );
    try {
      final available = await _repo.availableSlots(propertyId, day);
      if (isClosed || request != _dayRequest) return;
      final slots = available
          .map(
            (slot) => SlotInfo(
              startLocal: slot.startsAtUtc.toLocal(),
              startUtcMs: slot.startsAtUtc.millisecondsSinceEpoch,
              available: slot.available,
            ),
          )
          .toList();
      emit(BookingState(status: BookingStatus.ready, day: day, slots: slots));
    } catch (e) {
      if (isClosed || request != _dayRequest) return;
      emit(
        BookingState(
          status: BookingStatus.failure,
          day: day,
          error: apiErrorMessage(e),
        ),
      );
    }
  }

  void select(SlotInfo slot) {
    if (isClosed ||
        !slot.available ||
        state.status == BookingStatus.submitting) {
      return;
    }
    emit(
      state.copyWith(
        status: BookingStatus.ready,
        selectedUtcMs: slot.startUtcMs,
        clearBooked: true,
      ),
    );
  }

  Future<bool> submit({
    required String buyerId,
    required String buyerName,
    required String buyerPhone,
  }) async {
    if (isClosed || state.status == BookingStatus.submitting) return false;
    final selected = state.selectedUtcMs;
    if (selected == null) return false;
    emit(state.copyWith(status: BookingStatus.submitting, error: null));
    try {
      final viewing = await _repo.book(
        propertyId: propertyId,
        startsAtUtc: DateTime.fromMillisecondsSinceEpoch(selected, isUtc: true),
        buyerId: buyerId,
        buyerName: buyerName,
        buyerPhone: buyerPhone,
      );
      if (isClosed) return true;
      emit(state.copyWith(status: BookingStatus.success, booked: viewing));
      return true;
    } on SlotUnavailableException catch (e) {
      if (isClosed) return false;
      emit(state.copyWith(status: BookingStatus.failure, error: e.message));
      final day = state.day;
      if (day != null) await loadDay(day);
      return false;
    } catch (e) {
      if (isClosed) return false;
      emit(
        state.copyWith(
          status: BookingStatus.failure,
          error: apiErrorMessage(e),
        ),
      );
      return false;
    }
  }
}
