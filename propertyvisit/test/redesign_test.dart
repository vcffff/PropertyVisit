import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:propertyvisit/app.dart';
import 'package:propertyvisit/core/data/mock_store.dart';
import 'package:propertyvisit/core/network/api_client.dart';
import 'package:propertyvisit/features/auth/data/auth_repository.dart';
import 'package:propertyvisit/features/properties/data/property_repository.dart';
import 'package:propertyvisit/features/viewings/data/viewing_repository.dart';

const _capture = bool.fromEnvironment('CAPTURE_REVIEW');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting('ru');
    if (_capture) {
      await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
            rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
    // Local widget-render evidence, not a native-device screenshot or baseline.
    if (_capture && Platform.isWindows) {
      final file = File(r'C:\Windows\Fonts\segoeui.ttf');
      if (file.existsSync()) {
        final bytes = ByteData.sublistView(file.readAsBytesSync());
        for (final family in [
          'Roboto',
          'CupertinoSystemText',
          'CupertinoSystemDisplay',
        ]) {
          await (FontLoader(family)..addFont(Future.value(bytes))).load();
        }
      }
    }
  });

  Future<MockStore> launch(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double scale = 1,
    Brightness brightness = Brightness.light,
    String? role = 'buyer',
    PropertyRepository Function(MockStore)? properties,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    FlutterSecureStorage.setMockInitialValues(
      role == null ? {} : {'pv_session_role': role},
    );
    final auth = MockAuthRepository(const FlutterSecureStorage());
    final store = MockStore.seed();
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('review'),
        child: PropertyVisitApp(
          authRepository: auth,
          propertyRepository:
              properties?.call(store) ?? MockPropertyRepository(store),
          viewingRepository: MockViewingRepository(store),
          apiClient: ApiClient(accessTokenProvider: auth.accessToken),
        ),
      ),
    );
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    return store;
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!_capture) return;
    // Image decode happens outside the test clock; settle it before evidence.
    await tester.runAsync(() async {
      final context = tester.element(find.byType(MaterialApp));
      await Future.wait(
        List.generate(
          6,
          (i) => precacheImage(
            AssetImage('assets/properties/interior-${i + 1}.jpg'),
            context,
          ),
        ),
      );
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('review')),
      );
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('../.impeccable/review/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('catalog search, filters, sorting, and empty recovery', (
    tester,
  ) async {
    await launch(tester);
    expect(find.text('Объекты: 6'), findsOneWidget);
    await capture(tester, 'phone-android-widget');
    await tester.enterText(find.byType(TextField), 'Highvill');
    await tester.pumpAndSettle();
    expect(find.text('Объекты: 1'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'not-a-property');
    await tester.pumpAndSettle();
    expect(find.text('Ничего не найдено'), findsOneWidget);
    await capture(tester, 'empty-android-widget');
    await tester.tap(find.text('Сбросить поиск'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Все города'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<String>, 'Алматы'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Объекты: 2'), findsOneWidget);
    await tester.tap(find.text('Комнаты'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<int>, '2 комнаты'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Объекты: 1'), findsOneWidget);
    expect(find.text('ЖК «Арман»'), findsOneWidget);
    await tester.tap(find.text('По цене ↑'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сначала дороже'));
    await tester.pumpAndSettle();
    expect(find.text('По цене ↓'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('details to booking, confirmation and cancellation dialog', (
    tester,
  ) async {
    final store = await launch(tester);
    await tester.tap(find.text('Мои просмотры').last);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Каталог').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ЖК «Достык Residences»'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.text('Записаться на просмотр'), findsOneWidget);
    await capture(tester, 'details-android-widget');
    await tester.tap(find.text('Записаться на просмотр'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    await tester.tap(find.text('${tomorrow.day}').first);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10:00'));
    await tester.pumpAndSettle();
    await capture(tester, 'booking-android-widget');
    await tester.tap(find.text('Подтвердить бронирование'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Просмотр забронирован'), findsOneWidget);
    expect(store.viewings.length, 4);
    await capture(tester, 'success-android-widget');
    await tester.tap(find.text('Мои просмотры'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await capture(tester, 'viewings-android-widget');
    await tester.scrollUntilVisible(
      find.text('ЖК «Достык Residences»'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('ЖК «Достык Residences»'), findsOneWidget);
    await tester.tap(find.text('Отменить просмотр').first);
    await tester.pumpAndSettle();
    expect(find.text('Оставить запись'), findsOneWidget);
    await tester.tap(find.text('Оставить запись'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'manager rejects invalid numbers and preserves form on create failure',
    (tester) async {
      await launch(
        tester,
        role: 'admin',
        properties: (store) => _FailingCreateRepository(store),
      );
      await tester.tap(find.text('Добавить'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      for (final entry in {
        0: 'Новая квартира',
        2: 'ул. Тестовая, 1',
        3: '0',
        4: '-1',
        5: 'NaN',
      }.entries) {
        await tester.ensureVisible(fields.at(entry.key));
        await tester.enterText(fields.at(entry.key), entry.value);
      }
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(find.text('Введите число больше 0'), findsNWidgets(2));
      expect(find.text('Введите площадь больше 0'), findsOneWidget);
      for (final entry in {3: '10000000', 4: '1 0', 5: '42'}.entries) {
        await tester.ensureVisible(fields.at(entry.key));
        await tester.enterText(fields.at(entry.key), entry.value);
      }
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(find.text('Новая квартира'), findsNWidgets(2));
      expect(find.textContaining('Данные сохранены в форме'), findsOneWidget);
      await tester.ensureVisible(
        find.textContaining('Данные сохранены в форме'),
      );
      await capture(tester, 'manager-create-error-widget');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('manager can leave demo account through guarded logout', (
    tester,
  ) async {
    await launch(tester, role: 'admin');
    await tester.tap(find.byTooltip('Выйти'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выйти'));
    await tester.pumpAndSettle();
    expect(find.text('Попробуйте демо'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (
      name: 'large-text-android-widget',
      size: const Size(320, 740),
      scale: 1.3,
      brightness: Brightness.light,
    ),
    (
      name: 'dark-android-widget',
      size: const Size(390, 844),
      scale: 1.0,
      brightness: Brightness.dark,
    ),
    (
      name: 'tablet-android-widget',
      size: const Size(1024, 900),
      scale: 1.0,
      brightness: Brightness.light,
    ),
  ]) {
    testWidgets('${scenario.name}: responsive catalog and viewings', (
      tester,
    ) async {
      await launch(
        tester,
        size: scenario.size,
        scale: scenario.scale,
        brightness: scenario.brightness,
      );
      expect(find.text('Объекты: 6'), findsOneWidget);
      await capture(tester, scenario.name);
      await tester.tap(find.text('Мои просмотры').last);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('login validates and demo buyer access works', (tester) async {
    await launch(tester, role: null);
    await capture(tester, 'login-android-widget');
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();
    expect(find.text('Введите email'), findsOneWidget);
    await tester.ensureVisible(find.text('Покупатель'));
    await tester.tap(find.text('Покупатель'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Объекты: 6'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('manager add property opens below the correct provider', (
    tester,
  ) async {
    await launch(tester, role: 'admin');
    await capture(tester, 'manager-properties-widget');
    await tester.tap(find.text('Добавить'));
    await tester.pumpAndSettle();
    expect(find.text('Новая квартира'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('manager bookings render with readable buyer contact details', (
    tester,
  ) async {
    await launch(tester, role: 'admin');
    await tester.tap(find.text('Бронирования').last);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await capture(tester, 'manager-bookings-widget');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'iOS widgets retain native tabs and back navigation',
    (tester) async {
      await launch(tester);
      await capture(tester, 'phone-ios-widget');
      await tester.tap(find.text('ЖК «Достык Residences»'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Объекты: 6'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}

class _FailingCreateRepository extends MockPropertyRepository {
  _FailingCreateRepository(super.store);
  @override
  Future<Never> create({
    required String title,
    required String address,
    required String city,
    required int price,
    required int rooms,
    required double area,
    required String description,
  }) async => throw Exception('offline');
}
