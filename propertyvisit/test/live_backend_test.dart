import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:propertyvisit/core/network/api_client.dart';
import 'package:propertyvisit/features/auth/data/auth_repository.dart';
import 'package:propertyvisit/features/properties/data/property_repository.dart';
import 'package:propertyvisit/features/viewings/data/viewing_repository.dart';
import 'package:propertyvisit/features/viewings/domain/viewing.dart';

// Opt-in: creates a real user and one real pending viewing. Never runs in CI by
// accident. Admin credentials are environment variables, not command-line defines.
const liveUrl = String.fromEnvironment('LIVE_API_URL');

class _PacedRequests extends Interceptor {
  // Give other local clients' requests a full limiter window to expire first.
  DateTime? _last = DateTime.now().add(const Duration(seconds: 52));
  Future<void> _queue = Future.value();
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _queue = _queue.then((_) async {
      final last = _last;
      if (last != null) {
        final delay =
            const Duration(seconds: 13) - DateTime.now().difference(last);
        if (!delay.isNegative) await Future<void>.delayed(delay);
      }
      _last = DateTime.now();
      handler.next(options);
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'live Go API buyer booking and optional admin confirmation',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      // The Flutter widget-test binding replaces real HTTP with synthetic 400s.
      // Only this explicit opt-in test may use the real socket implementation.
      final previousOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      addTearDown(() => HttpOverrides.global = previousOverrides);
      final client = ApiClient(baseUrl: liveUrl);
      final pacing = _PacedRequests();
      client.authDio.interceptors.add(pacing);
      client.dio.interceptors.add(pacing);
      final auth = ApiAuthRepository(client);
      final properties = ApiPropertyRepository(client);
      final viewings = ApiViewingRepository(client, properties);
      final nonce = DateTime.now().microsecondsSinceEpoch;
      final email = 'flutter-smoke-$nonce@example.com';
      final random = Random.secure();
      final password = List.generate(
        32,
        (_) => random.nextInt(16).toRadixString(16),
      ).join();
      try {
        await client.authDio.post<void>(
          '/register',
          data: {'email': email, 'password': password},
        );
        final user = await auth.login(email, password);
        final items = await properties.getProperties();
        if (items.isEmpty) {
          fail('Live backend has no properties. An admin must create one.');
        }
        final property = items.first;
        final tomorrow = DateTime.now().toUtc().add(
          const Duration(hours: 5, days: 1),
        );
        final slots = await viewings.availableSlots(property.id, tomorrow);
        final free = slots.where((s) => s.available).toList();
        if (free.isEmpty) {
          fail('No available slots on the live backend tomorrow.');
        }
        final booked = await viewings.book(
          propertyId: property.id,
          startsAtUtc: free.first.startsAtUtc,
          buyerId: user.id,
          buyerName: '',
          buyerPhone: '',
        );
        // Non-secret IDs make cleanup possible even if a later check is interrupted.
        // ignore: avoid_print
        print(
          'Live test created viewing ${booked.id}, property ${property.id}.',
        );
        expect(booked.status, ViewingStatus.pending);
        expect(booked.buyerId, user.id);
        expect(
          (await viewings.myViewings('ignored')).any((v) => v.id == booked.id),
          isTrue,
        );
        try {
          await viewings.book(
            propertyId: property.id,
            startsAtUtc: free.first.startsAtUtc,
            buyerId: user.id,
            buyerName: '',
            buyerPhone: '',
          );
          fail('Duplicate live booking must return 409');
        } on SlotUnavailableException {
          /* Expected database conflict. */
        }
        final refreshed = await viewings.availableSlots(property.id, tomorrow);
        expect(
          refreshed
              .singleWhere((s) => s.startsAtUtc == free.first.startsAtUtc)
              .available,
          isFalse,
        );
        await client.refresh();
        expect((await auth.restore())?.id, user.id);

        final adminEmail = Platform.environment['PV_ADMIN_EMAIL'];
        final adminPassword = Platform.environment['PV_ADMIN_PASSWORD'];
        if (adminEmail != null && adminPassword != null) {
          await auth.logout();
          await auth.login(adminEmail, adminPassword);
          expect((await viewings.all()).any((v) => v.id == booked.id), isTrue);
          final confirmed = await viewings.setStatus(
            booked.id,
            ViewingStatus.confirmed,
          );
          expect(confirmed.status, ViewingStatus.confirmed);
          // Clean up the occupied slot through the documented admin transition.
          await viewings.setStatus(booked.id, ViewingStatus.cancelled);
        } else {
          // No role switching, guessed credentials, or backend modification.
          // ignore: avoid_print
          print(
            'Admin live verification BLOCKED: PV_ADMIN_EMAIL/PV_ADMIN_PASSWORD not supplied. '
            'Created pending viewing ${booked.id}, property ${property.id}; admin can cancel it.',
          );
        }
        await auth.logout();
      } on DioException catch (e) {
        fail('Live backend: ${apiErrorMessage(e)}');
      } on AuthException catch (e) {
        fail('Live authentication: ${e.message}');
      }
    },
    skip: liveUrl.isEmpty
        ? 'Opt-in only: --dart-define=LIVE_API_URL=http://localhost:8080/api/v1'
        : false,
    timeout: const Timeout(Duration(minutes: 7)),
  );
}
