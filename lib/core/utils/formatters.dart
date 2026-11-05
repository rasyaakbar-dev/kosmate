class Formatters {
  /// Formats numeric amount to Indonesian Rupiah representation: e.g. Rp 1.500.000
  static String formatCurrency(num amount) {
    final intVal = amount.round();
    final str = intVal.toString();
    final buffer = StringBuffer();
    int count = 0;

    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write('.');
      }
    }

    final formatted = buffer.toString().split('').reversed.join('');
    return 'Rp $formatted';
  }

  /// Formats DateTime to readable string: YYYY-MM-DD
  static String formatDate(DateTime? date) {
    if (date == null) return '-';
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Formats DateTime with time: YYYY-MM-DD HH:mm
  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '-';
    final date = formatDate(dateTime);
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$date $hour:$minute';
  }
}

