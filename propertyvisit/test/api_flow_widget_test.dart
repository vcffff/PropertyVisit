import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:propertyvisit/app.dart';
import 'package:propertyvisit/core/utils/formatters.dart';
import 'package:propertyvisit/features/auth/data/auth_repository.dart';
import 'package:propertyvisit/features/properties/data/property_repository.dart';
import 'package:propertyvisit/features/viewings/data/viewing_repository.dart';

import 'api_integration_test.dart' as fixtures;

const captureUi = bool.fromEnvironment('CAPTURE_MVP_UI');

Future<void> capture(WidgetTester tester, String name) async {
  if (!captureUi) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('api-review')),
    );
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('../.impeccable/review/api-mvp-$name-widget.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting('ru');
    if (captureUi) {
      await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
            rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
          ))
          .load();
    }
    if (captureUi && Platform.isWindows) {
      // Widget review only: Segoe substitutes for device fonts, not a golden.
      final bytes = ByteData.sublistView(
        File(r'C:\Windows\Fonts\segoeui.ttf').readAsBytesSync(),
      );
      for (final family in [
        'Roboto',
        'CupertinoSystemText',
        'CupertinoSystemDisplay',
      ]) {
        await (FontLoader(family)..addFont(Future.value(bytes))).load();
      }
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets(
    'registration validates passwords, creates account, then offers login',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var registrations = 0;
      final client = fixtures.clientWith((r) {
        expect(r.path, '/register');
        expect(r.method, 'POST');
        expect(r.headers.containsKey('Authorization'), isFalse);
        expect(r.data, {'email': 'new@example.com', 'password': 'secret123'});
        registrations++;
        return fixtures.jsonResponse({
          'id': 42,
          'email': 'new@example.com',
          'role': 'user',
          'created_at': '2030-10-01T09:00:00Z',
          'updated_at': '2030-10-01T09:00:00Z',
        }, 201);
      });
      final properties = ApiPropertyRepository(client);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('api-review'),
          child: PropertyVisitApp(
            authRepository: ApiAuthRepository(client),
            propertyRepository: properties,
            viewingRepository: ApiViewingRepository(client, properties),
            apiClient: client,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Создать аккаунт'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(3));
      expect(find.byIcon(LucideIcons.eye), findsNWidgets(2));
      bool obscured(int index) => tester
          .widget<EditableText>(
            find.descendant(
              of: fields.at(index),
              matching: find.byType(EditableText),
            ),
          )
          .obscureText;
      expect(obscured(1), isTrue);
      expect(obscured(2), isTrue);
      await tester.tap(find.byTooltip('Показать повтор пароля'));
      await tester.pumpAndSettle();
      expect(obscured(2), isFalse);
      expect(obscured(1), isTrue);
      expect(find.byIcon(LucideIcons.eyeOff), findsOneWidget);
      await tester.tap(find.byTooltip('Скрыть повтор пароля'));
      await tester.pumpAndSettle();
      expect(obscured(2), isTrue);
      await tester.enterText(fields.at(0), 'new@example.com');
      await tester.enterText(fields.at(1), '123');
      await tester.enterText(fields.at(2), 'different');
      await tester.ensureVisible(find.text('Зарегистрироваться'));
      await tester.tap(find.text('Зарегистрироваться'));
      await tester.pumpAndSettle();
      expect(find.text('Минимум 6 символов'), findsOneWidget);
      expect(find.text('Пароли не совпадают'), findsOneWidget);
      expect(registrations, 0);
      await tester.enterText(fields.at(1), 'secret123');
      await tester.enterText(fields.at(2), 'secret123');
      await tester.pumpAndSettle();
      await capture(tester, 'registration');
      await tester.ensureVisible(find.text('Зарегистрироваться'));
      await tester.tap(find.text('Зарегистрироваться'));
      await tester.pumpAndSettle();
      expect(registrations, 1);
      expect(await client.tokens(), isNull); // Register is not an auth session.
      expect(find.textContaining('Аккаунт создан.'), findsOneWidget);
      expect(find.text('Войти'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'new@example.com',
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).last)
            .controller!
            .text,
        'secret123',
      );
    },
  );

  testWidgets(
    'production wiring books without invented contact fields or demo access',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final astana = DateTime.now().toUtc().add(
        const Duration(hours: 5, days: 1),
      );
      final start = DateTime.utc(astana.year, astana.month, astana.day, 5);
      var booked = false;
      Map<String, dynamic> viewing() =>
          fixtures.viewingJson()..['starts_at'] = start.toIso8601String();
      final client = fixtures.clientWith((r) {
        switch (r.path) {
          case '/login':
            return fixtures.jsonResponse({
              'access_token': 'test-access',
              'refresh_token': 'test-refresh',
              'role': 'user',
              'token_type': 'Bearer',
              'expires_in': 900,
            });
          case '/users/me':
            return fixtures.jsonResponse({
              'id': 11,
              'email': 'buyer@example.com',
              'role': 'user',
            });
          case '/properties':
            return fixtures.jsonResponse([
              {
                'id': 2,
                'title': 'API Apartment',
                'address': 'Astana',
                'price': 45000000,
              },
            ]);
          case '/properties/2':
            return fixtures.jsonResponse({
              'id': 2,
              'title': 'Apartment',
              'address': 'Astana',
              'price': 45000000,
              'cover_image_url': null,
              'images': [],
            });
          case '/properties/2/available-slots':
            return fixtures.jsonResponse({
              'property_id': 2,
              'date': r.queryParameters['date'],
              'slots': [
                {'starts_at': start.toIso8601String(), 'available': true},
              ],
            });
          case '/viewings':
            booked = true;
            return fixtures.jsonResponse(viewing(), 201);
          case '/viewings/me':
            return fixtures.jsonResponse(booked ? [viewing()] : []);
          default:
            fail('Unexpected API request ${r.path}');
        }
      });
      final properties = ApiPropertyRepository(client);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('api-review'),
          child: PropertyVisitApp(
            authRepository: ApiAuthRepository(client),
            propertyRepository: properties,
            viewingRepository: ApiViewingRepository(client, properties),
            apiClient: client,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Попробуйте демо'), findsNothing);
      await capture(tester, 'login');
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'buyer@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password');
      await tester.tap(find.text('Войти'));
      await tester.pumpAndSettle();
      expect(find.text('API Apartment'), findsOneWidget);
      expect(find.byIcon(LucideIcons.building2), findsWidgets);
      expect(find.byIcon(LucideIcons.calendarCheck), findsWidgets);
      expect(find.text('Комнаты'), findsNothing);
      await capture(tester, 'catalog');
      await tester.tap(find.text('API Apartment'));
      await tester.pumpAndSettle();
      expect(find.text('Площадь'), findsNothing);
      await capture(tester, 'details');
      await tester.tap(find.text('Записаться на просмотр'));
      await tester.pumpAndSettle();
      expect(find.text('Телефон'), findsNothing);
      await tester.tap(find.text('${astana.day}').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(formatTime(start)));
      await tester.pumpAndSettle();
      await capture(tester, 'booking');
      await tester.tap(find.text('Подтвердить бронирование'));
      await tester.pumpAndSettle();
      expect(find.text('Просмотр забронирован'), findsOneWidget);
      await capture(tester, 'success');
      await tester.tap(find.text('Мои просмотры'));
      await tester.pumpAndSettle();
      expect(find.text('Ожидает'), findsOneWidget);
      expect(find.text('Отменить просмотр'), findsNothing);
      await capture(tester, 'viewings');
    },
  );
}
