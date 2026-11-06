import 'http_gateway.dart';
import 'models.dart';
import 'pagina.dart';
import 'api_error.dart';

abstract interface class AcessosRepository {
  bool get permiteCriarFuncionario;
  bool get suportaBusca;
  Future<Pagina<ContaAcesso>> listar(
    int page,
    int size,
    Map<String, String> filtros,
  );
  Future<void> ativo(int id, bool ativo);
  Future<Convite> convite(int clienteId);
  Future<void> criarFuncionario(Map<String, dynamic> dados);
}

class HttpAcessosRepository implements AcessosRepository {
  HttpAcessosRepository(
    this.http, {
    this.permiteCriarFuncionario = true,
    this.suportaBusca = false,
  });
  final HttpGateway http;
  // Habilitar na API real somente após o DTO ser confirmado pelo backend.
  @override
  final bool permiteCriarFuncionario;
  @override
  final bool suportaBusca;
  @override
  Future<Pagina<ContaAcesso>> listar(
    int page,
    int size,
    Map<String, String> filtros,
  ) async => Pagina.fromJson(
    await http.send(
      'GET',
      '/usuarios',
      query: {...filtros, 'page': '$page', 'size': '$size'},
    ),
    ContaAcesso.fromJson,
  );
  @override
  Future<void> ativo(int id, bool ativo) async {
    await http.send('PATCH', '/usuarios/$id/ativo', body: {'ativo': ativo});
  }

  @override
  Future<Convite> convite(int clienteId) async =>
      Convite.fromJson(await http.send('POST', '/clientes/$clienteId/convite'));
  @override
  Future<void> criarFuncionario(Map<String, dynamic> dados) async {
    if (!permiteCriarFuncionario) {
      throw const ApiException(
        'Cadastro de funcionário aguardando integração.',
      );
    }
    await http.send('POST', '/auth/funcionarios', body: dados);
  }
}
