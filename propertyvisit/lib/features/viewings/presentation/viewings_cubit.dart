import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/viewing_repository.dart';
import '../domain/viewing.dart';
import '../../../core/network/api_client.dart';

enum ViewingsStatus { loading, ready, failure }

class ViewingsState extends Equatable {
  const ViewingsState({
    required this.status,
    this.items = const [],
    this.error,
    this.updatingIds = const {},
  });
  const ViewingsState.loading() : this(status: ViewingsStatus.loading);
  const ViewingsState.failure(String error)
    : this(status: ViewingsStatus.failure, error: error);
  final ViewingsStatus status;
  final List<Viewing> items;
  final String? error;
  final Set<String> updatingIds;
  @override
  List<Object?> get props => [status, items, error, updatingIds];
}

class MyViewingsCubit extends Cubit<ViewingsState> {
  MyViewingsCubit(this._repo, {required this.buyerId})
    : super(const ViewingsState.loading());
  final ViewingRepository _repo;
  final String buyerId;
  Future<void> load() async {
    if (isClosed) return;
    emit(const ViewingsState.loading());
    try {
      final items = await _repo.myViewings(buyerId);
      if (!isClosed) {
        emit(ViewingsState(status: ViewingsStatus.ready, items: items));
      }
    } catch (e) {
      if (!isClosed) {
        emit(ViewingsState.failure(apiErrorMessage(e)));
      }
    }
  }

  Future<void> cancel(String viewingId) async {
    if (isClosed || !_repo.supportsBuyerCancellation) return;
    emit(ViewingsState(status: ViewingsStatus.ready, items: state.items));
    try {
      final updated = await _repo.setStatus(viewingId, ViewingStatus.cancelled);
      if (!isClosed) {
        emit(
          ViewingsState(
            status: ViewingsStatus.ready,
            items: state.items
                .map((v) => v.id == updated.id ? updated : v)
                .toList(),
          ),
        );
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          ViewingsState(
            status: ViewingsStatus.ready,
            items: state.items,
            error: 'Не удалось отменить просмотр. Попробуйте снова.',
          ),
        );
      }
    }
  }
}

class AdminViewingsCubit extends Cubit<ViewingsState> {
  AdminViewingsCubit(this._repo) : super(const ViewingsState.loading());
  final ViewingRepository _repo;
  Future<void> load() async {
    if (isClosed || state.updatingIds.isNotEmpty) return;
    emit(const ViewingsState.loading());
    try {
      final items = await _repo.all();
      if (!isClosed) {
        emit(ViewingsState(status: ViewingsStatus.ready, items: items));
      }
    } catch (e) {
      if (!isClosed) {
        emit(ViewingsState.failure(apiErrorMessage(e)));
      }
    }
  }

  Future<void> setStatus(String viewingId, ViewingStatus status) async {
    if (isClosed || state.updatingIds.contains(viewingId)) return;
    emit(
      ViewingsState(
        status: ViewingsStatus.ready,
        items: state.items,
        updatingIds: {...state.updatingIds, viewingId},
      ),
    );
    try {
      final updated = await _repo.setStatus(viewingId, status);
      if (!isClosed) {
        emit(
          ViewingsState(
            status: ViewingsStatus.ready,
            updatingIds: {...state.updatingIds}..remove(viewingId),
            items: state.items
                .map((v) => v.id == updated.id ? updated : v)
                .toList(),
          ),
        );
      }
    } catch (e) {
      if (!isClosed) {
        emit(
          ViewingsState(
            status: ViewingsStatus.ready,
            updatingIds: {...state.updatingIds}..remove(viewingId),
            items: state.items,
            error: apiErrorMessage(e),
          ),
        );
      }
    }
  }
}
