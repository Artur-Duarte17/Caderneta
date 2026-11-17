import 'http_gateway.dart';
import 'models.dart';
import 'consulta_paginada.dart';

abstract interface class DividasRepository {
  Future<void> renegociar(int id, DateTime data);
  Future<void> registrarPagamento(
    int dividaId,
    double valor,
    MetodoPagamento metodo,
  );
}

class HttpDividasRepository implements DividasRepository {
  HttpDividasRepository(this.http);
  final HttpGateway http;
  @override
  Future<void> renegociar(int id, DateTime data) =>
      http.send('PUT', '/dividas/$id', body: {'dataVencimento': isoDia(data)});
  @override
  Future<void> registrarPagamento(
    int dividaId,
    double valor,
    MetodoPagamento metodo,
  ) => http.send(
    'POST',
    '/dividas/$dividaId/pagamentos',
    body: {'valorPago': valor, 'metodoPagamento': metodo.name},
  );
}
