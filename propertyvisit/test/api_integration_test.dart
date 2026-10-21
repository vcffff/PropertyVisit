import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:propertyvisit/core/network/api_client.dart';
import 'package:propertyvisit/features/auth/data/auth_repository.dart';
import 'package:propertyvisit/features/auth/domain/user.dart';
import 'package:propertyvisit/features/properties/data/property_repository.dart';
import 'package:propertyvisit/features/viewings/data/viewing_repository.dart';
import 'package:propertyvisit/features/viewings/domain/viewing.dart';
import 'package:propertyvisit/features/viewings/presentation/booking_cubit.dart';
import 'package:propertyvisit/features/viewings/presentation/viewings_cubit.dart';

typedef Responder = FutureOr<ResponseBody> Function(RequestOptions request);

class ContractAdapter implements HttpClientAdapter {
  ContractAdapter(this.respond);
  final Responder respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => await respond(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Object? body, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

ApiClient clientWith(Responder respond) {
  final adapter = ContractAdapter(respond);
  return ApiClient(
    baseUrl: 'http://localhost:8080/api/v1',
    transport: Dio()..httpClientAdapter = adapter,
    authTransport: Dio()..httpClientAdapter = adapter,
  );
}

Map<String, dynamic> viewingJson({String status = 'pending'}) => {
  'id': 12,
  'user_id': 11,
  'property_id': 2,
  'starts_at': '2030-10-24T05:00:00Z',
  'status': status,
  'created_at': '2030-10-01T09:00:00Z',
  'updated_at': '2030-10-01T09:00:00Z',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'parallel 401s rotate once, persist both tokens, replay each request once',
    () async {
      var refreshes = 0, oldCalls = 0, newCalls = 0;
      final bothOld = Completer<void>();
      final client = clientWith((request) async {
        expect(request.uri.path.startsWith('/api/v1/'), isTrue);
        if (request.path == '/auth/refresh') {
          refreshes++;
          expect(request.headers.containsKey('Authorization'), isFalse);
          expect(request.data, {'refresh_token': 'old-refresh'});
          await bothOld.future;
          return jsonResponse({
            'access_token': 'new-access',
            'refresh_token': 'new-refresh',
          });
        }
        if (request.headers['Authorization'] == 'Bearer old-access') {
          oldCalls++;
          if (oldCalls == 2) bothOld.complete();
          return jsonResponse({'error': 'expired'}, 401);
        }
        newCalls++;
        expect(request.headers['Authorization'], 'Bearer new-access');
        return jsonResponse([]);
      });
      await client.startSession({
        'access_token': 'old-access',
        'refresh_token': 'old-refresh',
      });
      await Future.wait([
        client.dio.get<dynamic>('/properties'),
        client.dio.get<dynamic>('/viewings/me'),
      ]);
      expect(refreshes, 1);
      expect(oldCalls, 2);
      expect(newCalls, 2);
      expect((await client.tokens())!.access, 'new-access');
      expect((await client.tokens())!.refresh, 'new-refresh');
      final restored = ApiClient();
      expect((await restored.tokens())!.refresh, 'new-refresh');
    },
  );

  test('a delayed old-token 401 does not trigger another rotation', () async {
    final release = Completer<void>();
    final delayedStarted = Completer<void>();
    var refreshes = 0;
    final client = clientWith((r) async {
      if (r.path == '/auth/refresh') {
        refreshes++;
        return jsonResponse({
          'access_token': 'new',
          'refresh_token': 'rotated',
        });
      }
      if (r.headers['Authorization'] == 'Bearer old') {
        if (r.path == '/slow') {
          delayedStarted.complete();
          await release.future;
        }
        return jsonResponse({'error': 'expired'}, 401);
      }
      return jsonResponse([]);
    });
    await client.startSession({
      'access_token': 'old',
      'refresh_token': 'refresh',
    });
    final slow = client.dio.get<dynamic>('/slow');
    await delayedStarted.future;
    await client.dio.get<dynamic>('/fast');
    release.complete();
    await slow;
    expect(refreshes, 1);
  });

  test('retry 401 ends the session, never loops', () async {
    var refreshes = 0, calls = 0;
    final client = clientWith((r) {
      if (r.path == '/auth/refresh') {
        refreshes++;
        return jsonResponse({
          'access_token': 'new',
          'refresh_token': 'rotated',
        });
      }
      calls++;
      return jsonResponse({'error': 'unauthorized'}, 401);
    });
    await client.startSession({
      'access_token': 'old',
      'refresh_token': 'refresh',
    });
    await expectLater(
      client.dio.get<dynamic>('/properties'),
      throwsA(isA<DioException>()),
    );
    expect(refreshes, 1);
    expect(calls, 2);
    expect(await client.tokens(), isNull);
  });

  for (final status in [401, 429, 500]) {
    test(
      'refresh HTTP $status has no recursive retry; only 401 clears tokens',
      () async {
        var refreshes = 0;
        final client = clientWith((r) {
          if (r.path == '/auth/refresh') {
            refreshes++;
            return jsonResponse({'error': 'failure'}, status);
          }
          return jsonResponse({'error': 'expired'}, 401);
        });
        await client.startSession({
          'access_token': 'old',
          'refresh_token': 'refresh',
        });
        await expectLater(
          client.dio.get<dynamic>('/properties'),
          throwsA(isA<DioException>()),
        );
        expect(refreshes, 1);
        expect(await client.tokens(), status == 401 ? isNull : isNotNull);
      },
    );
  }

  test('rotation cannot resurrect a cleared session', () async {
    final started = Completer<void>(), response = Completer<ResponseBody>();
    final client = clientWith((r) {
      started.complete();
      return response.future;
    });
    await client.startSession({
      'access_token': 'old',
      'refresh_token': 'refresh',
    });
    final refresh = client.refresh();
    final assertion = expectLater(refresh, throwsStateError);
    await started.future;
    await client.clearSession();
    response.complete(
      jsonResponse({'access_token': 'new', 'refresh_token': 'rotated'}),
    );
    await assertion;
    expect(await client.tokens(), isNull);
  });

  test(
    'logout revokes refresh without Authorization, local session is cleared even on 500',
    () async {
      final client = clientWith((r) {
        expect(r.path, '/auth/logout');
        expect(r.data, {'refresh_token': 'refresh'});
        expect(r.headers.containsKey('Authorization'), isFalse);
        return jsonResponse({'error': 'unavailable'}, 500);
      });
      await client.startSession({
        'access_token': 'access',
        'refresh_token': 'refresh',
      });
      await expectLater(client.logout(), throwsA(isA<DioException>()));
      expect(await client.tokens(), isNull);
    },
  );

  test(
    'login → catalog → slots → booking → own viewings → admin confirmation follows contract',
    () async {
      var status = 'pending';
      final client = clientWith((r) {
        switch (r.path) {
          case '/login':
            expect(r.data, {
              'email': 'user@example.com',
              'password': 'password',
            });
            expect(r.headers.containsKey('Authorization'), isFalse);
            return jsonResponse({
              'access_token': 'access',
              'refresh_token': 'refresh',
              'token_type': 'Bearer',
              'expires_in': 900,
              'role': 'user',
            });
          case '/users/me':
            return jsonResponse({
              'id': 11,
              'email': 'user@example.com',
              'role': 'user',
            });
          case '/properties':
            return jsonResponse([
              {
                'id': 2,
                'title': 'Apartment',
                'address': 'Astana',
                'price': 45000000,
              },
            ]);
          case '/properties/2':
            return jsonResponse({
              'id': 2,
              'title': 'Apartment',
              'address': 'Astana',
              'price': 45000000,
              'cover_image_url': null,
              'images': [],
            });
          case '/properties/2/available-slots':
            expect(r.queryParameters, {'date': '2030-10-24'});
            return jsonResponse({
              'property_id': 2,
              'date': '2030-10-24',
              'slots': [
                {'starts_at': '2030-10-24T05:00:00Z', 'available': true},
                {'starts_at': '2030-10-24T05:30:00Z', 'available': false},
              ],
            });
          case '/viewings':
            expect(r.data, {
              'property_id': 2,
              'starts_at': '2030-10-24T05:00:00Z',
            });
            return jsonResponse(viewingJson(), 201);
          case '/viewings/me':
          case '/admin/viewings':
            expect(
              r.queryParameters,
              isEmpty,
            ); // Ownership comes only from JWT.
            return jsonResponse([viewingJson(status: status)]);
          case '/admin/viewings/12/status':
            expect(r.method, 'PATCH');
            expect(r.data, {'status': 'confirmed'});
            status = 'confirmed';
            return jsonResponse(viewingJson(status: status));
          default:
            fail('Undocumented request: ${r.method} ${r.path}');
        }
      });
      final auth = ApiAuthRepository(client);
      final user = await auth.login('user@example.com', 'password');
      expect(user.role, UserRole.buyer);
      final properties = ApiPropertyRepository(client);
      final property = (await properties.getProperties()).single;
      expect(property.hasExtendedDetails, isFalse);
      expect(property.photoUrl, isEmpty);
      expect((await properties.getProperty('2')).title, 'Apartment');
      final viewings = ApiViewingRepository(client, properties);
      final booking = BookingCubit(viewings, propertyId: '2');
      await booking.loadDay(DateTime(2030, 10, 24));
      expect(booking.state.slots.length, 2); // Do not synthesize missing slots.
      final slot = booking.state.slots.first;
      expect(slot.startLocal, DateTime.parse('2030-10-24T05:00:00Z').toLocal());
      expect(booking.state.slots.last.available, isFalse);
      booking.select(slot);
      expect(
        await booking.submit(
          buyerId: 'not-sent',
          buyerName: 'not-sent',
          buyerPhone: 'not-sent',
        ),
        isTrue,
      );
      expect(booking.state.booked!.status, ViewingStatus.pending);
      expect(
        (await viewings.myViewings('not-sent')).single.propertyTitle,
        'Apartment',
      );
      final admin = AdminViewingsCubit(viewings);
      await admin.load();
      await admin.setStatus('12', ViewingStatus.confirmed);
      expect(admin.state.items.single.status, ViewingStatus.confirmed);
      expect(
        (await viewings.myViewings('11')).single.status,
        ViewingStatus.confirmed,
      );
      expect(viewings.supportsBuyerCancellation, isFalse);
      await booking.close();
      await admin.close();
    },
  );

  test('409 booking refreshes availability and clears selection', () async {
    var booked = false, availabilityCalls = 0;
    final client = clientWith((r) {
      if (r.path == '/viewings') {
        booked = true;
        return jsonResponse({'error': 'occupied'}, 409);
      }
      availabilityCalls++;
      return jsonResponse({
        'property_id': 2,
        'date': '2030-10-24',
        'slots': [
          {'starts_at': '2030-10-24T05:00:00Z', 'available': !booked},
        ],
      });
    });
    final repo = ApiViewingRepository(client, ApiPropertyRepository(client));
    final cubit = BookingCubit(repo, propertyId: '2');
    await cubit.loadDay(DateTime(2030, 10, 24));
    cubit.select(cubit.state.slots.single);
    expect(
      await cubit.submit(buyerId: '11', buyerName: '', buyerPhone: ''),
      isFalse,
    );
    expect(availabilityCalls, 2);
    expect(cubit.state.selectedUtcMs, isNull);
    expect(cubit.state.slots.single.available, isFalse);
    await cubit.close();
  });

  test(
    '403 never refreshes, empty lists stay empty, all four statuses decode',
    () async {
      final client = clientWith((r) {
        if (r.path == '/viewings/me') return jsonResponse([]);
        expect(r.path, '/admin/viewings');
        return jsonResponse({'error': 'forbidden'}, 403);
      });
      final repo = ApiViewingRepository(client, ApiPropertyRepository(client));
      expect(await repo.myViewings('999'), isEmpty);
      await expectLater(repo.all(), throwsA(isA<DioException>()));
      for (final status in ViewingStatus.values) {
        expect(
          Viewing.fromJson(viewingJson(status: status.name)).status,
          status,
        );
      }
    },
  );
}
