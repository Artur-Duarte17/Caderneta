import 'http_gateway.dart';
export 'api_error.dart';
export 'http_gateway.dart' show apiBaseUrl;

import 'models.dart';
import 'pagina.dart';

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

  Future<Pagina<T>> pagina<T>(
    String path,
    T Function(Map<String, dynamic>) f, {
    int page = 0,
    int size = 20,
    String q = '',
    String? status,
    int periodo = 0,
  }) async {
    final query = {
      'page': '$page',
      'size': '$size',
      if (q.isNotEmpty) 'q': q,
      'status': ?status,
      if (periodo > 0)
        'inicio': isoDia(DateTime.now().subtract(Duration(days: periodo - 1))),
      if (periodo > 0) 'fim': isoDia(DateTime.now()),
    };
    final r = await _send('GET', path, query: query);
    return Pagina.fromJson(r, f);
  }

  String isoDia(DateTime d) => d.toIso8601String().substring(0, 10);
  Future<List<T>> _list<T>(
    String path,
    T Function(Map<String, dynamic>) f,
  ) async => (await pagina(path, f, size: 100)).content;
  Future<Map<String, dynamic>> resumo({bool pessoal = false}) async =>
      Map<String, dynamic>.from(
        await _send('GET', pessoal ? '/me/resumo' : '/resumo'),
      );
  Future<void> renegociar(int id, DateTime data) =>
      _send('PUT', '/dividas/$id', body: {'dataVencimento': isoDia(data)});
  Future<void> excluirVenda(int id) => _send('DELETE', '/vendas/$id');
  Future<List<Pagamento>> relatorioPagamentos(
    String inicio,
    String fim,
  ) async =>
      ((await _send(
                'GET',
                '/relatorios/pagamentos',
                query: {'inicio': inicio, 'fim': fim},
              ))
              as List)
          .map((p) => Pagamento.fromJson(p))
          .toList();

  // Clientes
  Future<List<Cliente>> clientesRelatorio(String inicio, String fim) async =>
      ((await _send(
                'GET',
                '/relatorios/clientes',
                query: {'inicio': inicio, 'fim': fim},
              ))
              as List)
          .map((c) => Cliente.fromJson(c))
          .toList();
  Future<List<Cliente>> clientes() => _list('/clientes', Cliente.fromJson);
  Future<Cliente> cliente(int id) async =>
      Cliente.fromJson(await _send('GET', '/clientes/$id'));

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

  Future<void> criarVenda(
    int clienteId,
    List<ItemVenda> itens, {
    required double valorTotal,
  }) => _send(
    'POST',
    '/vendas',
    body: {
      'clienteId': clienteId,
      'valorTotal': valorTotal,
      'itens': itens.map((i) => i.toJson()).toList(),
    },
  );

  Future<void> atualizarVenda(
    int id, {
    required int clienteId,
    required double valorTotal,
    required int versao,
    required List<ItemVenda> itens,
    DateTime? data,
  }) => _send(
    'PUT',
    '/vendas/$id',
    body: {
      'clienteId': clienteId,
      'valorTotal': valorTotal,
      'versao': versao,
      'itens': itens.map((i) => i.toJson()).toList(),
      if (data != null) 'dataHora': data.toUtc().toIso8601String(),
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

  Future<Map<String, dynamic>> resumoRelatorio(
    String inicio,
    String fim,
  ) async => Map<String, dynamic>.from(
    await _send(
      'GET',
      '/relatorios/resumo',
      query: {'inicio': inicio, 'fim': fim},
    ),
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
  Snapshot(
    this.clientes,
    this.vendas,
    this.dividas, {
    this.page = 0,
    this.total = 0,
    this.last = true,
  }) : _clientePorId = {for (final c in clientes) c.id: c},
       _dividaPorId = {for (final d in dividas) d.id: d};

  final int page, total;
  final bool last;
  final List<Cliente> clientes;
  final List<Venda> vendas;
  final List<Divida> dividas;
  final Map<int, Cliente> _clientePorId;
  final Map<int, Divida> _dividaPorId;

  static Future<Snapshot> load({
    String recurso = 'vendas',
    int page = 0,
    String q = '',
    String? status,
    int periodo = 0,
  }) async {
    final api = Api.instance;
    final raw = await api.gateway.send(
      'GET',
      '/$recurso',
      query: {
        'page': '$page',
        'size': '20',
        if (q.isNotEmpty) 'q': q,
        'status': ?status,
        if (periodo > 0)
          'inicio': api.isoDia(
            DateTime.now().subtract(Duration(days: periodo - 1)),
          ),
        if (periodo > 0) 'fim': api.isoDia(DateTime.now()),
      },
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
    for (final v in vendas) {
      s._nomes[v.clienteId] = v.clienteNome ?? 'Cliente #${v.clienteId}';
    }
    for (final d in dividas) {
      s._nomes[d.clienteId] = d.clienteNome ?? 'Cliente #${d.clienteId}';
    }
    return s;
  }

  final _nomes = <int, String>{};

  String nomeCliente(int id) =>
      _clientePorId[id]?.nome ?? _nomes[id] ?? 'Cliente #$id';
  Cliente? cliente(int id) => _clientePorId[id];
  Divida? divida(int? id) => id == null ? null : _dividaPorId[id];

  Status? statusVenda(Venda v) =>
      divida(v.dividaId)?.status ??
      Status.values.where((s) => s.backend == v.statusDivida).firstOrNull;

  Iterable<Divida> dividasDe(int clienteId) =>
      dividas.where((d) => d.clienteId == clienteId);

  double saldoDevedor(int clienteId) =>
      _clientePorId[clienteId]?.saldoDevedor ??
      dividasDe(clienteId)
          .where((d) => d.status.emAberto)
          .fold<double>(0, (s, d) => s + d.valorPendente);

  bool emAtraso(int clienteId) =>
      _clientePorId[clienteId]?.emAtraso ??
      dividasDe(clienteId).any((d) => d.status == Status.vencida);
}
