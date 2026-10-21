import '../../../core/data/mock_store.dart';
import '../../../core/network/api_client.dart';
import 'package:dio/dio.dart';
import '../../properties/data/property_repository.dart';
import '../domain/slots.dart';
import '../domain/viewing.dart';

class SlotUnavailableException implements Exception {
  const SlotUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class ViewingRepository {
  bool get supportsBuyerCancellation => false;
  Future<List<AvailableSlot>> availableSlots(String propertyId, DateTime day);

  /// Epoch-ms начала занятых (активных) слотов объекта на локальный день [day].
  /// Отменённые просмотры слот освобождают.
  Future<Set<int>> bookedSlotStarts(String propertyId, DateTime day);

  /// Время старта передаётся в UTC. Бросает [SlotUnavailableException],
  /// если слот уже занят — защита дубля на стороне бэкенда (partial unique index).
  Future<Viewing> book({
    required String propertyId,
    required DateTime startsAtUtc,
    required String buyerId,
    required String buyerName,
    required String buyerPhone,
  });

  Future<List<Viewing>> myViewings(String buyerId);

  /// Все бронирования — для админа.
  Future<List<Viewing>> all();

  Future<Viewing> setStatus(String viewingId, ViewingStatus status);
}

class AvailableSlot {
  const AvailableSlot({required this.startsAtUtc, required this.available});
  final DateTime startsAtUtc;
  final bool available;
  factory AvailableSlot.fromJson(Map<String, dynamic> json) => AvailableSlot(
    startsAtUtc: DateTime.parse(json['starts_at'] as String).toUtc(),
    available: json['available'] as bool,
  );
}

class ApiViewingRepository extends ViewingRepository {
  ApiViewingRepository(this.client, this.properties);
  final ApiClient client;
  final ApiPropertyRepository properties;

  Viewing _parse(Map<String, dynamic> json) {
    final viewing = Viewing.fromJson(json);
    final property = properties.cached(viewing.propertyId);
    if (property == null) return viewing;
    return Viewing(
      id: viewing.id,
      propertyId: viewing.propertyId,
      propertyTitle: property.title,
      propertyAddress: property.displayAddress,
      propertyPhotoUrl: property.photoUrl,
      startsAtUtc: viewing.startsAtUtc,
      status: viewing.status,
      buyerId: viewing.buyerId,
      buyerName: viewing.buyerName,
      buyerPhone: '',
      hasBuyerContact: false,
    );
  }

  @override
  Future<List<AvailableSlot>> availableSlots(
    String propertyId,
    DateTime day,
  ) async {
    final date =
        '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final response = await client.dio.get<Map<String, dynamic>>(
      '/properties/$propertyId/available-slots',
      queryParameters: {'date': date},
    );
    return (response.data!['slots'] as List<dynamic>)
        .map((e) => AvailableSlot.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Set<int>> bookedSlotStarts(String propertyId, DateTime day) async =>
      (await availableSlots(propertyId, day))
          .where((s) => !s.available)
          .map((s) => s.startsAtUtc.millisecondsSinceEpoch)
          .toSet();

  @override
  Future<Viewing> book({
    required String propertyId,
    required DateTime startsAtUtc,
    required String buyerId,
    required String buyerName,
    required String buyerPhone,
  }) async {
    try {
      final response = await client.dio.post<Map<String, dynamic>>(
        '/viewings',
        data: {
          'property_id': int.parse(propertyId),
          'starts_at': startsAtUtc.toUtc().toIso8601String().replaceFirst(
            '.000Z',
            'Z',
          ),
        },
      );
      return _parse(response.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw const SlotUnavailableException(
          'Это время уже занято. Выберите другой слот.',
        );
      }
      rethrow;
    }
  }

  Future<List<Viewing>> _list(String path) async {
    final response = await client.dio.get<List<dynamic>>(path);
    return response.data!
        .map((e) => _parse(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<Viewing>> myViewings(String buyerId) => _list('/viewings/me');
  @override
  Future<List<Viewing>> all() => _list('/admin/viewings');
  @override
  Future<Viewing> setStatus(String viewingId, ViewingStatus status) async {
    final response = await client.dio.patch<Map<String, dynamic>>(
      '/admin/viewings/$viewingId/status',
      data: {'status': status.name},
    );
    return _parse(response.data!);
  }
}

class MockViewingRepository extends ViewingRepository {
  MockViewingRepository(this._store);

  final MockStore _store;
  @override
  bool get supportsBuyerCancellation => true;
  @override
  Future<List<AvailableSlot>> availableSlots(
    String propertyId,
    DateTime day,
  ) async {
    final booked = await bookedSlotStarts(propertyId, day);
    return slotsForDay(day)
        .map(
          (local) => AvailableSlot(
            startsAtUtc: local.toUtc(),
            available:
                !booked.contains(local.toUtc().millisecondsSinceEpoch) &&
                !isSlotInPast(local, DateTime.now()),
          ),
        )
        .toList();
  }

  @override
  Future<Set<int>> bookedSlotStarts(String propertyId, DateTime day) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return _store.viewings
        .where(
          (v) =>
              v.propertyId == propertyId &&
              v.status != ViewingStatus.cancelled &&
              !v.startsAtUtc.toLocal().isBefore(dayStart) &&
              v.startsAtUtc.toLocal().isBefore(dayEnd),
        )
        .map((v) => v.startsAtUtc.toUtc().millisecondsSinceEpoch)
        .toSet();
  }

  @override
  Future<Viewing> book({
    required String propertyId,
    required DateTime startsAtUtc,
    required String buyerId,
    required String buyerName,
    required String buyerPhone,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final startUtc = startsAtUtc.toUtc();
    final conflict = _store.viewings.any(
      (v) =>
          v.propertyId == propertyId &&
          v.status != ViewingStatus.cancelled &&
          v.startsAtUtc.toUtc().millisecondsSinceEpoch ==
              startUtc.millisecondsSinceEpoch,
    );
    if (conflict) {
      throw const SlotUnavailableException('Это время уже занято');
    }
    final property = _store.properties.firstWhere((p) => p.id == propertyId);
    final viewing = Viewing(
      id: _store.nextViewingId(),
      propertyId: propertyId,
      propertyTitle: property.title,
      propertyAddress: '${property.city}, ${property.address}',
      propertyPhotoUrl: property.photoUrl,
      startsAtUtc: startUtc,
      status: ViewingStatus.pending,
      buyerId: buyerId,
      buyerName: buyerName,
      buyerPhone: buyerPhone,
    );
    _store.viewings.add(viewing);
    return viewing;
  }

  @override
  Future<List<Viewing>> myViewings(String buyerId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return _store.viewings.where((v) => v.buyerId == buyerId).toList()
      ..sort((a, b) => b.startsAtUtc.compareTo(a.startsAtUtc));
  }

  @override
  Future<List<Viewing>> all() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return _store.viewings.toList()
      ..sort((a, b) => a.startsAtUtc.compareTo(b.startsAtUtc));
  }

  @override
  Future<Viewing> setStatus(String viewingId, ViewingStatus status) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final index = _store.viewings.indexWhere((v) => v.id == viewingId);
    if (index == -1) {
      throw StateError('Просмотр $viewingId не найден');
    }
    final updated = Viewing(
      id: _store.viewings[index].id,
      propertyId: _store.viewings[index].propertyId,
      propertyTitle: _store.viewings[index].propertyTitle,
      propertyAddress: _store.viewings[index].propertyAddress,
      propertyPhotoUrl: _store.viewings[index].propertyPhotoUrl,
      startsAtUtc: _store.viewings[index].startsAtUtc,
      status: status,
      buyerId: _store.viewings[index].buyerId,
      buyerName: _store.viewings[index].buyerName,
      buyerPhone: _store.viewings[index].buyerPhone,
    );
    _store.viewings[index] = updated;
    return updated;
  }
}
