import 'models.dart';

/// Índices e agregados do relatório: independentes do layout e da exportação.
class DadosRelatorio {
  DadosRelatorio(
    this.vendas,
    this.dividas,
    this.clientes,
    this.pagamentos,
    this.resumo,
  ) {
    for (final c in clientes) {
      _nomes[c.id] = c.nome;
    }
    for (final d in dividas) {
      _dividas[d.id] = d;
      if (d.clienteNome != null) {
        _nomes.putIfAbsent(d.clienteId, () => d.clienteNome!);
      }
    }
    for (final v in vendas) {
      if (v.clienteNome != null) {
        _nomes.putIfAbsent(v.clienteId, () => v.clienteNome!);
      }
      _totais[v.clienteId] = (_totais[v.clienteId] ?? 0) + v.valorTotal;
    }
  }
  final List<Venda> vendas;
  final List<Divida> dividas;
  final List<Cliente> clientes;
  final List<Pagamento> pagamentos;
  final Map<String, dynamic> resumo;
  final _nomes = <int, String>{};
  final _dividas = <int, Divida>{};
  final _totais = <int, double>{};
  String nome(int id) => _nomes[id] ?? 'Cliente #$id';
  double totalCliente(int id) => _totais[id] ?? 0;
  Status? statusVenda(Venda v) =>
      _dividas[v.dividaId]?.status ??
      Status.values.where((s) => s.backend == v.statusDivida).firstOrNull;
}
