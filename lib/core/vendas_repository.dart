import 'http_gateway.dart';
import 'models.dart';

abstract interface class VendasRepository {
  Future<Venda> venda(int id);
  Future<void> excluirVenda(int id);
  Future<void> criarVenda(
    int clienteId,
    List<ItemVenda> itens, {
    required double valorTotal,
  });
  Future<void> atualizarVenda(
    int id, {
    required int clienteId,
    required double valorTotal,
    required int versao,
    required List<ItemVenda> itens,
    DateTime? data,
  });
}

class HttpVendasRepository implements VendasRepository {
  HttpVendasRepository(this.http);
  final HttpGateway http;
  @override
  Future<void> excluirVenda(int id) => http.send('DELETE', '/vendas/$id');
  @override
  Future<Venda> venda(int id) async =>
      Venda.fromJson(await http.send('GET', '/vendas/$id'));

  @override
  Future<void> criarVenda(
    int clienteId,
    List<ItemVenda> itens, {
    required double valorTotal,
  }) => http.send(
    'POST',
    '/vendas',
    body: {
      'clienteId': clienteId,
      'valorTotal': valorTotal,
      'itens': itens.map((i) => i.toJson()).toList(),
    },
  );

  @override
  Future<void> atualizarVenda(
    int id, {
    required int clienteId,
    required double valorTotal,
    required int versao,
    required List<ItemVenda> itens,
    DateTime? data,
  }) => http.send(
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
}
