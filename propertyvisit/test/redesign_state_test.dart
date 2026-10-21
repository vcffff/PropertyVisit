import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:propertyvisit/core/data/mock_store.dart';
import 'package:propertyvisit/core/utils/validators.dart';
import 'package:propertyvisit/features/viewings/data/viewing_repository.dart';
import 'package:propertyvisit/features/viewings/domain/viewing.dart';
import 'package:propertyvisit/features/viewings/presentation/booking_cubit.dart';
import 'package:propertyvisit/features/viewings/presentation/viewings_cubit.dart';

class _ControlledRepository extends MockViewingRepository {
  _ControlledRepository(super.store);
  final requests = <Completer<Set<int>>>[];
  @override
  Future<Set<int>> bookedSlotStarts(String propertyId, DateTime day) {
    final result = Completer<Set<int>>();
    requests.add(result);
    return result.future;
  }

  @override
  Future<Viewing> setStatus(String viewingId, ViewingStatus status) async =>
      throw Exception('offline');
}

void main() {
  test(
    'price, room and area validation rejects zero, negative and non-finite values',
    () {
      for (final value in ['', '0', '-1', 'NaN', 'Infinity', '-Infinity']) {
        expect(positiveInteger(value), isNotNull);
        expect(positiveArea(value), isNotNull);
      }
      expect(positiveInteger('48 000 000'), isNull);
      expect(positiveArea('42,5'), isNull);
    },
  );

  test('latest selected day wins out-of-order availability requests', () async {
    final repo = _ControlledRepository(MockStore.seed());
    final cubit = BookingCubit(repo, propertyId: 'p1');
    final first = DateTime(2030, 1, 1), second = DateTime(2030, 1, 2);
    final a = cubit.loadDay(first), b = cubit.loadDay(second);
    repo.requests[1].complete({});
    await b;
    repo.requests[0].complete({});
    await a;
    expect(cubit.state.day, second);
    expect(
      cubit.state.slots.every((slot) => slot.startLocal.day == second.day),
      isTrue,
    );
    await cubit.close();
  });

  test(
    'dismissed booking does not emit after availability completes',
    () async {
      final repo = _ControlledRepository(MockStore.seed());
      final cubit = BookingCubit(repo, propertyId: 'p1');
      final loading = cubit.loadDay(DateTime(2030));
      await cubit.close();
      repo.requests.single.complete({});
      await expectLater(loading, completes);
    },
  );

  test(
    'buyer cancellation failure preserves visible items and exposes recovery',
    () async {
      final repo = _ControlledRepository(MockStore.seed());
      final cubit = MyViewingsCubit(repo, buyerId: 'u-buyer');
      await cubit.load();
      final before = cubit.state.items;
      await cubit.cancel(before.first.id);
      expect(cubit.state.status, ViewingsStatus.ready);
      expect(cubit.state.items, before);
      expect(cubit.state.error, isNotNull);
      await cubit.close();
    },
  );

  test(
    'manager status failure preserves visible items and exposes recovery',
    () async {
      final repo = _ControlledRepository(MockStore.seed());
      final cubit = AdminViewingsCubit(repo);
      await cubit.load();
      final before = cubit.state.items;
      await cubit.setStatus(before.first.id, ViewingStatus.confirmed);
      expect(cubit.state.status, ViewingsStatus.ready);
      expect(cubit.state.items, before);
      expect(cubit.state.error, isNotNull);
      await cubit.close();
    },
  );
}
