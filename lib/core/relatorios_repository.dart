import 'http_gateway.dart';
import 'models.dart';

abstract interface class RelatoriosRepository {
  Future<List<Pagamento>> relatorioPagamentos(String inicio, String fim);
  Future<List<Cliente>> clientesRelatorio(String inicio, String fim);
  Future<Map<String, dynamic>> resumoRelatorio(String inicio, String fim);
  Future<List<Venda>> relatorioVendas(String inicio, String fim);
  Future<List<Divida>> relatorioDividas(String inicio, String fim);
}

class HttpRelatoriosRepository implements RelatoriosRepository {
  HttpRelatoriosRepository(this.http);
  final HttpGateway http;
  @override
  Future<List<Pagamento>> relatorioPagamentos(
    String inicio,
    String fim,
  ) async =>
      ((await http.send(
                'GET',
                '/relatorios/pagamentos',
                query: {'inicio': inicio, 'fim': fim},
              ))
              as List)
          .map((p) => Pagamento.fromJson(p))
          .toList();

  @override
  Future<List<Cliente>> clientesRelatorio(String inicio, String fim) async =>
      ((await http.send(
                'GET',
                '/relatorios/clientes',
                query: {'inicio': inicio, 'fim': fim},
              ))
              as List)
          .map((c) => Cliente.fromJson(c))
          .toList();
  @override
  Future<Map<String, dynamic>> resumoRelatorio(
    String inicio,
    String fim,
  ) async => Map<String, dynamic>.from(
    await http.send(
      'GET',
      '/relatorios/resumo',
      query: {'inicio': inicio, 'fim': fim},
    ),
  );

  // Relatórios
  @override
  Future<List<Venda>> relatorioVendas(String inicio, String fim) async {
    final r = await http.send(
      'GET',
      '/relatorios/vendas-a-prazo',
      query: {'dataInicio': inicio, 'dataFim': fim},
    );
    return ((r?['vendas'] as List?) ?? [])
        .map((e) => Venda.fromJson(e))
        .toList();
  }

  @override
  Future<List<Divida>> relatorioDividas(String inicio, String fim) async {
    final r = await http.send(
      'GET',
      '/relatorios/debitos-pendentes',
      query: {'dataInicio': inicio, 'dataFim': fim},
    );
    return ((r?['dividas'] as List?) ?? [])
        .map((e) => Divida.fromJson(e))
        .toList();
  }
}
