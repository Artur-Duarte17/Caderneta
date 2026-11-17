import 'http_gateway.dart';
import 'models.dart';
import 'pagina.dart';
import 'consulta_paginada.dart';

abstract interface class ClientesRepository {
  Future<void> alterarAtivo(int id, bool ativo);
  Future<Pagina<Cliente>> pagina({int page = 0, int size = 20, String q = ''});
  Future<List<Cliente>> clientes();
  Future<Cliente> cliente(int id);
  Future<Cliente> criarCliente(Map<String, dynamic> dados);
  Future<void> atualizarCliente(int id, Map<String, dynamic> dados);
  Future<void> criarFiadorParaCliente(
    int clienteId,
    Map<String, dynamic> dados,
  );
}

class HttpClientesRepository implements ClientesRepository {
  HttpClientesRepository(this.http);
  final HttpGateway http;
  @override
  Future<void> alterarAtivo(int id, bool ativo) =>
      http.send('PATCH', '/clientes/$id/ativo', body: {'ativo': ativo});
  @override
  Future<Pagina<Cliente>> pagina({
    int page = 0,
    int size = 20,
    String q = '',
  }) async => Pagina.fromJson(
    await http.send(
      'GET',
      '/clientes',
      query: consultaPaginada(page: page, size: size, q: q),
    ),
    Cliente.fromJson,
  );
  @override
  Future<List<Cliente>> clientes() => pagina(size: 100).then((p) => p.content);
  @override
  Future<Cliente> cliente(int id) async =>
      Cliente.fromJson(await http.send('GET', '/clientes/$id'));

  @override
  Future<Cliente> criarCliente(Map<String, dynamic> dados) async =>
      Cliente.fromJson(await http.send('POST', '/clientes', body: dados));

  @override
  Future<void> atualizarCliente(int id, Map<String, dynamic> dados) =>
      http.send('PUT', '/clientes/$id', body: dados);

  @override
  Future<void> criarFiadorParaCliente(
    int clienteId,
    Map<String, dynamic> dados,
  ) async {
    final fiador = await http.send('POST', '/fiadores', body: dados);
    await http.send(
      'POST',
      '/fiadores/associar/cliente/$clienteId/fiador/${fiador['id']}',
    );
  }
}
