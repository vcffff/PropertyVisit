/// Фиксированная сетка просмотров: ежедневно 10:00–19:00, слоты по 30 минут.
/// Время объекта = локальное время устройства (MVP), хранение — в UTC.
library;

const workDayStartHour = 10;
const workDayEndHour = 19;
const slotDuration = Duration(minutes: 30);

/// Локальные времена начала слотов для [day] (любой момент внутри дня).
List<DateTime> slotsForDay(DateTime day) {
  final start = DateTime(day.year, day.month, day.day, workDayStartHour);
  final end = DateTime(day.year, day.month, day.day, workDayEndHour);
  final slots = <DateTime>[];
  for (var t = start; t.isBefore(end); t = t.add(slotDuration)) {
    slots.add(t);
  }
  return slots;
}

/// Слот недоступен, если он уже начался (или начнётся в течение часа).
bool isSlotInPast(DateTime localSlotStart, DateTime now) =>
    localSlotStart.add(slotDuration).isBefore(now) ||
    localSlotStart.isBefore(now.add(const Duration(hours: 1)));
