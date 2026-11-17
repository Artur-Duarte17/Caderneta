String isoDia(DateTime d) => d.toIso8601String().substring(0, 10);
Map<String, String> consultaPaginada({
  int page = 0,
  int size = 20,
  String q = '',
  String? status,
  int periodo = 0,
}) => {
  'page': '$page',
  'size': '$size',
  if (q.isNotEmpty) 'q': q,
  'status': ?status,
  if (periodo > 0)
    'inicio': isoDia(DateTime.now().subtract(Duration(days: periodo - 1))),
  if (periodo > 0) 'fim': isoDia(DateTime.now()),
};
