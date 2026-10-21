import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/property_repository.dart';
import '../domain/property.dart';
import '../../../core/network/api_client.dart';

enum PropertiesStatus { loading, ready, failure }

class PropertiesState extends Equatable {
  const PropertiesState({
    required this.status,
    this.items = const [],
    this.error,
  });

  const PropertiesState.loading() : this(status: PropertiesStatus.loading);
  const PropertiesState.failure(String error)
    : this(status: PropertiesStatus.failure, error: error);

  final PropertiesStatus status;
  final List<Property> items;
  final String? error;

  @override
  List<Object?> get props => [status, items, error];
}

class PropertiesCubit extends Cubit<PropertiesState> {
  PropertiesCubit(this._repo) : super(const PropertiesState.loading());

  final PropertyRepository _repo;
  int _request = 0;
  Future<void>? _inFlight;

  /// Rebuilds/navigation reuse loaded state. Only explicit refresh hits the API.
  Future<void> load() {
    if (isClosed) return Future.value();
    if (_inFlight != null) return _inFlight!;
    if (state.status == PropertiesStatus.ready) return Future.value();
    return refresh();
  }

  Future<void> refresh() {
    if (isClosed) return Future.value();
    return _inFlight ??= _fetch().whenComplete(() => _inFlight = null);
  }

  Future<void> _fetch() async {
    if (isClosed) return;
    final request = ++_request;
    final hadCatalog = state.status == PropertiesStatus.ready;
    emit(
      PropertiesState(
        status: hadCatalog ? PropertiesStatus.ready : PropertiesStatus.loading,
        items: state.items,
      ),
    );
    try {
      final items = await _repo.getProperties();
      if (isClosed || request != _request) return;
      emit(PropertiesState(status: PropertiesStatus.ready, items: items));
    } catch (e) {
      if (isClosed || request != _request) return;
      emit(
        PropertiesState(
          status: hadCatalog
              ? PropertiesStatus.ready
              : PropertiesStatus.failure,
          items: state.items,
          error: apiErrorMessage(e),
        ),
      );
    }
  }

  Future<bool> create({
    required String title,
    required String address,
    required String city,
    required int price,
    required int rooms,
    required double area,
    required String description,
  }) async {
    try {
      final property = await _repo.create(
        title: title,
        address: address,
        city: city,
        price: price,
        rooms: rooms,
        area: area,
        description: description,
      );
      if (isClosed) return true;
      ++_request; // A pending list response must not overwrite this creation.
      emit(
        PropertiesState(
          status: PropertiesStatus.ready,
          items: [property, ...state.items],
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
