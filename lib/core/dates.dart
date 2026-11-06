/// Datas puras preservam o dia; instantes são convertidos explicitamente pela UI.
DateTime? parseData(dynamic value) {
  if (value == null) return null;
  if (value is List && value.length >= 3) {
    final p = value.map((e) => (e as num).toInt()).toList();
    return DateTime(
      p[0],
      p[1],
      p[2],
      p.length > 3 ? p[3] : 0,
      p.length > 4 ? p[4] : 0,
      p.length > 5 ? p[5] : 0,
    );
  }
  return DateTime.tryParse('$value');
}

Map<String, String> limitesPeriodo(DateTime inicio, DateTime fim) => {
  'inicio': DateTime(
    inicio.year,
    inicio.month,
    inicio.day,
  ).toUtc().toIso8601String(),
  'fim': DateTime(fim.year, fim.month, fim.day + 1).toUtc().toIso8601String(),
};
