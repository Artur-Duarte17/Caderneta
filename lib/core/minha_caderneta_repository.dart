import 'http_gateway.dart';
import 'models.dart';
import 'pagina.dart';

abstract interface class MinhaCadernetaRepository {
  Future<Pagina<Venda>> compras(int page, int size);
  Future<Pagina<Divida>> dividas(int page, int size);
  Future<Pagina<Pagamento>> pagamentos(int page, int size);
}

class HttpMinhaCadernetaRepository implements MinhaCadernetaRepository {
  HttpMinhaCadernetaRepository(this.http);
  final HttpGateway http;
  Future<Pagina<T>> _get<T>(
    String recurso,
    int page,
    int size,
    T Function(Map<String, dynamic>) parse,
  ) async => Pagina.fromJson(
    await http.send(
      'GET',
      '/me/$recurso',
      query: {'page': '$page', 'size': '$size'},
    ),
    parse,
  );
  @override
  Future<Pagina<Venda>> compras(int page, int size) =>
      _get('vendas', page, size, Venda.fromJson);
  @override
  Future<Pagina<Divida>> dividas(int page, int size) =>
      _get('dividas', page, size, Divida.fromJson);
  @override
  Future<Pagina<Pagamento>> pagamentos(int page, int size) =>
      _get('pagamentos', page, size, Pagamento.fromJson);
}

class ResumoCaderneta {
  ResumoCaderneta(this.dividas, this.parcial);
  final List<Divida> dividas;
  final bool parcial;
  static Future<ResumoCaderneta> carregar(MinhaCadernetaRepository repo) async {
    final itens = <Divida>[];
    for (var page = 0; page < 10; page++) {
      final r = await repo.dividas(page, 100);
      itens.addAll(r.content.take(1000 - itens.length));
      if (r.last) return ResumoCaderneta(itens, false);
      if (itens.length >= 1000 || r.content.isEmpty) {
        return ResumoCaderneta(itens, true);
      }
    }
    return ResumoCaderneta(itens, true);
  }
}
