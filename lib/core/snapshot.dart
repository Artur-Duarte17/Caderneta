import 'models.dart';

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
       _dividaPorId = {for (final d in dividas) d.id: d} {
    for (final v in vendas) {
      _nomes[v.clienteId] = v.clienteNome ?? 'Cliente #${v.clienteId}';
    }
    for (final d in dividas) {
      _nomes[d.clienteId] = d.clienteNome ?? 'Cliente #${d.clienteId}';
    }
  }

  final int page, total;
  final bool last;
  final List<Cliente> clientes;
  final List<Venda> vendas;
  final List<Divida> dividas;
  final Map<int, Cliente> _clientePorId;
  final Map<int, Divida> _dividaPorId;

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
