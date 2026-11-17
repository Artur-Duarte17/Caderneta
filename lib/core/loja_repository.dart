import 'http_gateway.dart';

abstract interface class LojaRepository {
  Future<double> limitePadrao();
  Future<void> salvarLimite(double valor);
}

class HttpLojaRepository implements LojaRepository {
  HttpLojaRepository(this.http);
  final HttpGateway http;

  @override
  Future<double> limitePadrao() async {
    final dados = await http.send('GET', '/loja/configuracao');
    return (dados['limiteCreditoPadrao'] as num).toDouble();
  }

  @override
  Future<void> salvarLimite(double valor) => http.send(
    'PUT',
    '/loja/configuracao',
    body: {'limiteCreditoPadrao': valor},
  );
}
