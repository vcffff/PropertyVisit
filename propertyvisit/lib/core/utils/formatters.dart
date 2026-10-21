import 'package:intl/intl.dart';

const _slotDuration = Duration(minutes: 30);

String formatPrice(int price) =>
    '${NumberFormat.decimalPattern('ru').format(price)} ₸';

String formatDay(DateTime local) => DateFormat('d MMMM', 'ru').format(local);

String formatTime(DateTime utc) => DateFormat('HH:mm').format(utc.toLocal());

String formatViewingRange(DateTime startUtc) {
  final endUtc = startUtc.add(_slotDuration);
  return '${formatDay(startUtc.toLocal())}, ${formatTime(startUtc)}–${formatTime(endUtc)}';
}

String formatShortDate(DateTime local) =>
    DateFormat('d MMM', 'ru').format(local);
