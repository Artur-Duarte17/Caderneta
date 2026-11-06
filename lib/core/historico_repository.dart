import 'http_gateway.dart';
import 'models.dart';
import 'pagina.dart';

abstract interface class HistoricoRepository {
  Future<Pagina<EventoHistorico>> listar({
    required bool pessoal,
    int page = 0,
    int size = 20,
    Map<String, String> filtros = const {},
  });
}

class HttpHistoricoRepository implements HistoricoRepository {
  HttpHistoricoRepository(this.http);
  final HttpGateway http;
  @override
  Future<Pagina<EventoHistorico>> listar({
    required bool pessoal,
    int page = 0,
    int size = 20,
    Map<String, String> filtros = const {},
  }) async => Pagina.fromJson(
    await http.send(
      'GET',
      pessoal ? '/me/historico' : '/historico',
      query: {...filtros, 'page': '$page', 'size': '$size'},
    ),
    EventoHistorico.fromJson,
  );
}
