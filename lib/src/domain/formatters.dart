const _auKm = 149597870.7;

String formatDistance(double au) {
  if (au < 0.01) {
    final km = au * _auKm;
    return km >= 1000000
        ? '${(km / 1000000).toStringAsFixed(2)} 百万 km'
        : '${km.toStringAsFixed(km >= 10000 ? 0 : 1)} km';
  }
  return '${au.toStringAsFixed(au >= 10 ? 1 : 2)} AU';
}

String formatDuration(double days) {
  if (days < 2) return '${(days * 24).toStringAsFixed(1)} 小时';
  if (days < 730) return '${days.toStringAsFixed(days < 20 ? 1 : 0)} 天';
  return '${(days / 365.256).toStringAsFixed(1)} 年';
}

String formatDeltaV(double value) => '${value.toStringAsFixed(2)} km/s';

String formatCommunicationDelay(double minimum, double maximum) {
  if (maximum < 90) {
    return '${minimum.toStringAsFixed(1)}–${maximum.toStringAsFixed(1)} 秒';
  }
  return '${(minimum / 60).toStringAsFixed(1)}–${(maximum / 60).toStringAsFixed(1)} 分';
}

String formatRisk(double score) {
  final label = switch (score) {
    < 25 => '低',
    < 50 => '中低',
    < 72 => '中高',
    _ => '高',
  };
  return '$label ${score.round()}';
}

String formatSimulationDate(double dayFromJ2000) {
  final j2000 = DateTime.utc(2000, 1, 1, 12);
  final value = j2000.add(Duration(minutes: (dayFromJ2000 * 1440).round()));
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}.${two(value.month)}.${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)} UTC';
}
