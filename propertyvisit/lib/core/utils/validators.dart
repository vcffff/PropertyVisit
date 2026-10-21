String? positiveInteger(String? value) {
  final number = int.tryParse((value ?? '').replaceAll(RegExp(r'\s'), ''));
  return number == null || number <= 0 ? 'Введите число больше 0' : null;
}

String? positiveArea(String? value) {
  final number = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
  return number == null || !number.isFinite || number <= 0
      ? 'Введите площадь больше 0'
      : null;
}
