import 'package:flutter_test/flutter_test.dart';
import 'package:propertyvisit/features/viewings/domain/slots.dart';

void main() {
  group('slotsForDay', () {
    test('рабочий день 10:00–19:00 даёт 18 слотов по 30 минут', () {
      final slots = slotsForDay(DateTime(2026, 10, 24));
      expect(slots.length, 18);
      expect(slots.first.hour, 10);
      expect(slots.first.minute, 0);
      expect(slots.last.hour, 18);
      expect(slots.last.minute, 30);
    });

    test('первый слот через 30 минут после начала', () {
      final slots = slotsForDay(DateTime(2026, 10, 24));
      expect(slots[1].difference(slots[0]), const Duration(minutes: 30));
    });
  });

  group('isSlotInPast', () {
    test('слот, закончившийся час назад, в прошлом', () {
      final now = DateTime(2026, 10, 24, 12, 0);
      expect(isSlotInPast(DateTime(2026, 10, 24, 10, 30), now), isTrue);
    });

    test('слот через час и позже — не в прошлом', () {
      final now = DateTime(2026, 10, 24, 12, 0);
      expect(isSlotInPast(DateTime(2026, 10, 24, 13, 30), now), isFalse);
    });

    test('слот в пределах часа от текущего момента — в прошлом', () {
      final now = DateTime(2026, 10, 24, 12, 0);
      expect(isSlotInPast(DateTime(2026, 10, 24, 12, 30), now), isTrue);
    });
  });
}
