import 'http_gateway.dart';
export 'api_error.dart';
export 'http_gateway.dart' show apiBaseUrl;

import 'models.dart';

class Api {
  Api({required this.gateway});
  static Api instance = Api(gateway: HttpGateway());
  final HttpGateway gateway;

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
  }) => gateway.send(method, path, body: body, query: query);

  Future<List<T>> _list<T>(
    String path,
    T Function(Map<String, dynamic>) f,
  ) async =>
      ((await _send('GET', path) as List?) ?? []).map((e) => f(e)).toList();

  // Clientes
  Future<List<Cliente>> clientes() => _list('/clientes', Cliente.fromJson);

  Future<Cliente> criarCliente(Map<String, dynamic> dados) async =>
      Cliente.fromJson(await _send('POST', '/clientes', body: dados));

  Future<void> atualizarCliente(int id, Map<String, dynamic> dados) =>
      _send('PUT', '/clientes/$id', body: dados);

  Future<void> criarFiadorParaCliente(
    int clienteId,
    Map<String, dynamic> dados,
  ) async {
    final fiador = await _send('POST', '/fiadores', body: dados);
    await _send(
      'POST',
      '/fiadores/associar/cliente/$clienteId/fiador/${fiador['id']}',
    );
  }

  // Vendas
  Future<List<Venda>> vendas() => _list('/vendas', Venda.fromJson);

  Future<Venda> venda(int id) async =>
      Venda.fromJson(await _send('GET', '/vendas/$id'));

  Future<void> criarVenda(int clienteId, List<ItemVenda> itens) => _send(
    'POST',
    '/vendas',
    body: {
      'clienteId': clienteId,
      'itens': itens.map((i) => i.toJson()).toList(),
    },
  );

  Future<void> atualizarVenda(
    int id, {
    required int clienteId,
    required double valorTotal,
    DateTime? data,
  }) => _send(
    'PUT',
    '/vendas/$id',
    body: {
      'clienteId': clienteId,
      'valorTotal': valorTotal,
      if (data != null)
        'dataHora': '${data.toIso8601String().substring(0, 10)}T00:00:00',
    },
  );

  // Dívidas / pagamentos
  Future<List<Divida>> dividas() => _list('/dividas', Divida.fromJson);

  Future<void> registrarPagamento(
    int dividaId,
    double valor,
    MetodoPagamento metodo,
  ) => _send(
    'POST',
    '/dividas/$dividaId/pagamentos',
    body: {'valorPago': valor, 'metodoPagamento': metodo.name},
  );

  // Relatórios
  Future<List<Venda>> relatorioVendas(String inicio, String fim) async {
    final r = await _send(
      'GET',
      '/relatorios/vendas-a-prazo',
      query: {'dataInicio': inicio, 'dataFim': fim},
    );
    return ((r?['vendas'] as List?) ?? [])
        .map((e) => Venda.fromJson(e))
        .toList();
  }

  Future<List<Divida>> relatorioDividas(String inicio, String fim) async {
    final r = await _send(
      'GET',
      '/relatorios/debitos-pendentes',
      query: {'dataInicio': inicio, 'dataFim': fim},
    );
    return ((r?['dividas'] as List?) ?? [])
        .map((e) => Divida.fromJson(e))
        .toList();
  }
}

/// Dados combinados usados por várias telas (clientes + vendas + dívidas).
class Snapshot {
  Snapshot(this.clientes, this.vendas, this.dividas)
    : _clientePorId = {for (final c in clientes) c.id: c},
      _dividaPorId = {for (final d in dividas) d.id: d};

  final List<Cliente> clientes;
  final List<Venda> vendas;
  final List<Divida> dividas;
  final Map<int, Cliente> _clientePorId;
  final Map<int, Divida> _dividaPorId;

  static Future<Snapshot> load() async {
    final api = Api.instance;
    final r = await Future.wait([api.clientes(), api.vendas(), api.dividas()]);
    return Snapshot(
      r[0] as List<Cliente>,
      r[1] as List<Venda>,
      r[2] as List<Divida>,
    );
  }

  String nomeCliente(int id) => _clientePorId[id]?.nome ?? 'Cliente #$id';
  Cliente? cliente(int id) => _clientePorId[id];
  Divida? divida(int? id) => id == null ? null : _dividaPorId[id];

  Status? statusVenda(Venda v) => divida(v.dividaId)?.status;

  Iterable<Divida> dividasDe(int clienteId) =>
      dividas.where((d) => d.clienteId == clienteId);

  double saldoDevedor(int clienteId) => dividasDe(clienteId)
      .where((d) => d.status.emAberto)
      .fold<double>(0, (s, d) => s + d.valorPendente);

  bool emAtraso(int clienteId) =>
      dividasDe(clienteId).any((d) => d.status == Status.vencida);
}
