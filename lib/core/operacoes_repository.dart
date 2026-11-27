import 'http_gateway.dart';
import 'models.dart';
import 'snapshot.dart';
import 'consulta_paginada.dart';

abstract interface class OperacoesRepository {
  Future<Snapshot> carregar({
    String recurso = 'vendas',
    int page = 0,
    String q = '',
    String? status,
    int periodo = 0,
  });
  Future<Map<String, dynamic>> resumo({bool pessoal = false});
}

class HttpOperacoesRepository implements OperacoesRepository {
  HttpOperacoesRepository(this.http);
  final HttpGateway http;
  @override
  Future<Map<String, dynamic>> resumo({bool pessoal = false}) async =>
      Map<String, dynamic>.from(
        await http.send('GET', pessoal ? '/me/resumo' : '/resumo'),
      );
  @override
  Future<Snapshot> carregar({
    String recurso = 'vendas',
    int page = 0,
    String q = '',
    String? status,
    int periodo = 0,
  }) async {
    final raw = await http.send(
      'GET',
      '/$recurso',
      query: consultaPaginada(
        page: page,
        q: q,
        status: status,
        periodo: periodo,
      ),
    );
    final rows = (raw['content'] as List).cast<Map<String, dynamic>>();
    final clientes = recurso == 'clientes'
        ? rows.map(Cliente.fromJson).toList()
        : <Cliente>[];
    final vendas = recurso == 'vendas'
        ? rows.map(Venda.fromJson).toList()
        : <Venda>[];
    final dividas = recurso == 'dividas'
        ? rows.map(Divida.fromJson).toList()
        : <Divida>[];
    final s = Snapshot(
      clientes,
      vendas,
      dividas,
      page: raw['number'],
      total: raw['totalElements'],
      last: raw['last'],
    );
    return s;
  }
}
