import 'http_gateway.dart';
import 'models.dart';
import 'pagina.dart';

abstract interface class AuditoriaRepository {
  Future<Pagina<AuditoriaEvento>> listar(
    int page,
    int size,
    Map<String, String> filtros,
  );
}

class HttpAuditoriaRepository implements AuditoriaRepository {
  HttpAuditoriaRepository(this.http);
  final HttpGateway http;
  @override
  Future<Pagina<AuditoriaEvento>> listar(
    int page,
    int size,
    Map<String, String> filtros,
  ) async => Pagina.fromJson(
    await http.send(
      'GET',
      '/auditoria',
      query: {...filtros, 'page': '$page', 'size': '$size'},
    ),
    AuditoriaEvento.fromJson,
  );
}

/// A lista é recursivamente sanitizada antes de qualquer renderização.
dynamic semSegredos(dynamic value) {
  final segredo = RegExp(
    r'senha|password|hash|token|codigo|código|secret|cookie|authorization',
    caseSensitive: false,
  );
  if (value is Map) {
    return {
      for (final e in value.entries)
        if (!segredo.hasMatch(e.key.toString()))
          e.key.toString(): semSegredos(e.value),
    };
  }
  if (value is List) return value.map(semSegredos).toList();
  return value;
}
