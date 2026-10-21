import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:propertyvisit/core/theme/app_theme.dart';
import 'package:propertyvisit/core/widgets/property_photo.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'Lucide back icon preserves native BackButton behavior ($brightness)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: brightness == Brightness.dark
                ? AppTheme.dark
                : AppTheme.light,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Details')),
                      ),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.byType(BackButton), findsOneWidget);
        expect(find.byIcon(LucideIcons.arrowLeftDir), findsOneWidget);
        expect(
          tester.getSize(find.byType(BackButton)).shortestSide,
          greaterThanOrEqualTo(48),
        );
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Open'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'missing photo uses the same Lucide family without compact thumbnail overflow',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 76,
                height: 76,
                child: PropertyPhoto(source: ''),
              ),
            ),
          ),
        ),
      );
      expect(find.byIcon(LucideIcons.imageOff), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
