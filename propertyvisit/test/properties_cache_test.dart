import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:propertyvisit/app.dart';
import 'package:propertyvisit/features/auth/data/auth_repository.dart';
import 'package:propertyvisit/features/properties/presentation/screens/catalog_screen.dart';
import 'package:propertyvisit/features/properties/presentation/screens/property_details_screen.dart';
import 'package:propertyvisit/features/viewings/data/viewing_repository.dart';
import 'package:propertyvisit/core/data/mock_store.dart';
import 'package:propertyvisit/core/widgets/property_image_widget.dart';
import 'package:propertyvisit/features/properties/data/property_repository.dart';
import 'package:propertyvisit/features/properties/domain/property.dart';
import 'package:propertyvisit/features/properties/presentation/properties_cubit.dart';

import 'api_integration_test.dart' as fixtures;

class _ControlledRepository extends MockPropertyRepository {
  _ControlledRepository() : super(MockStore.seed());
  final requests = <Completer<List<Property>>>[];

  @override
  Future<List<Property>> getProperties() {
    final request = Completer<List<Property>>();
    requests.add(request);
    return request.future;
  }
}

class _CountingRepository extends MockPropertyRepository {
  _CountingRepository(super.store);
  int catalogCalls = 0;
  @override
  Future<List<Property>> getProperties() {
    catalogCalls++;
    return super.getProperties();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  setUpAll(() => initializeDateFormatting('ru'));

  testWidgets(
    'Details back/reopen and many lazy cards retain the catalog; refresh is explicit',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      FlutterSecureStorage.setMockInitialValues({'pv_session_role': 'buyer'});
      final store = MockStore.seed();
      store.properties
        ..clear()
        ..addAll(
          List.generate(
            80,
            (i) => Property(
              id: 'p$i',
              title: 'Property $i',
              address: 'Astana',
              city: '',
              price: i + 1,
              rooms: 1,
              area: 40,
              photoUrl: '',
              description: '',
            ),
          ),
        );
      final repo = _CountingRepository(store);
      final auth = MockAuthRepository(const FlutterSecureStorage());
      final client = fixtures.clientWith((_) => fixtures.jsonResponse([]));
      await tester.pumpWidget(
        PropertyVisitApp(
          authRepository: auth,
          propertyRepository: repo,
          viewingRepository: MockViewingRepository(store),
          apiClient: client,
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(repo.catalogCalls, 1);
      expect(find.byType(PropertyCard).evaluate().length, lessThan(80));
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byType(PropertyImageWidget).first);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
        expect(find.byType(PropertyDetailsScreen), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(repo.catalogCalls, 1);
      }
      final refresh = tester
          .element(find.byType(PropertyCard).first)
          .read<PropertiesCubit>()
          .refresh();
      await tester.pump(const Duration(milliseconds: 400));
      await refresh;
      await tester.pumpAndSettle();
      expect(repo.catalogCalls, 2);
      for (var i = 0; i < 12; i++) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
        await tester.pumpAndSettle();
      }
      expect(find.byType(PropertyCard).evaluate().length, lessThan(80));
      expect(repo.catalogCalls, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test(
    'load coalesces requests and reuses catalog until explicit refresh',
    () async {
      final repo = _ControlledRepository();
      final cubit = PropertiesCubit(repo);
      final first = cubit.load();
      final duplicate = cubit.load();
      expect(identical(first, duplicate), isTrue);
      final items = MockStore.seed().properties;
      repo.requests.single.complete(items);
      await first;
      await cubit.load();
      expect(repo.requests, hasLength(1));
      final refresh = cubit.refresh();
      expect(cubit.state.items, items);
      expect(cubit.state.status, PropertiesStatus.ready);
      expect(identical(refresh, cubit.refresh()), isTrue);
      repo.requests.last.complete([]);
      await refresh;
      expect(cubit.state.items, isEmpty);
      await cubit.close();
    },
  );

  test('refresh failure retains catalog and allows retry', () async {
    final repo = _ControlledRepository();
    final cubit = PropertiesCubit(repo);
    final first = cubit.load();
    repo.requests.single.complete(MockStore.seed().properties);
    await first;
    final before = cubit.state.items;
    final refresh = cubit.refresh();
    repo.requests.last.completeError(Exception('offline'));
    await refresh;
    expect(cubit.state.status, PropertiesStatus.ready);
    expect(cubit.state.items, before);
    expect(cubit.state.error, isNotNull);
    final retry = cubit.refresh();
    repo.requests.last.complete([]);
    await retry;
    expect(cubit.state.error, isNull);
    await cubit.close();
  });

  test('closing catalog during a request is safe', () async {
    final repo = _ControlledRepository();
    final cubit = PropertiesCubit(repo);
    final loading = cubit.load();
    await cubit.close();
    repo.requests.single.complete([]);
    await expectLater(loading, completes);
  });

  test(
    'API list and detail requests coalesce independently; details reuse JSON',
    () async {
      var calls = 0;
      final response = Completer<void>();
      final json = {
        'id': 2,
        'title': 'Apartment',
        'address': 'Astana',
        'price': 10,
      };
      final client = fixtures.clientWith((r) async {
        calls++;
        await response.future;
        return fixtures.jsonResponse(r.path == '/properties' ? [json] : json);
      });
      final repo = ApiPropertyRepository(client);
      final a = repo.getProperties(), b = repo.getProperties();
      expect(identical(a, b), isTrue);
      final detail = repo.getProperty('2');
      expect(identical(detail, repo.getProperty('2')), isTrue);
      response.complete();
      await Future.wait([a, detail]);
      await repo.getProperty('2');
      expect(calls, 2);
      await repo.getProperties();
      expect(
        calls,
        3,
      ); // An explicit catalog refresh is not hidden by JSON caching.
      client.dio.close();
    },
  );
}
