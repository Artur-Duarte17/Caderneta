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

  /// Promove funcionário a gerente (ou o inverso). O login e a senha continuam os mesmos.
  Future<void> alterarPerfil(int id, Perfil perfil);
  Future<Convite> convite(int clienteId);

  /// Cria a conta; se o CPF for de um funcionário excluído, o backend reativa a conta antiga
  /// (mesmo login) e responde reativado=true.
  Future<ContaCriada> criarFuncionario(Map<String, dynamic> dados);

  /// Exclusão lógica: desativa e esconde a conta; nada é apagado.
  Future<void> excluir(int id);

  /// Restaura conta excluída com senha nova.
  Future<void> restaurar(int id, String senha);
}

class ContaCriada {
  const ContaCriada({required this.login, required this.reativado});
  final String login;
  final bool reativado;
  factory ContaCriada.fromJson(dynamic j) => ContaCriada(
    login: j is Map ? '${j['login'] ?? ''}' : '',
    reativado: j is Map && j['reativado'] == true,
  );
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
  Future<void> alterarPerfil(int id, Perfil perfil) async {
    await http.send(
      'PATCH',
      '/usuarios/$id/perfil',
      body: {'perfil': perfil == Perfil.gerente ? 'GERENTE' : 'FUNCIONARIO'},
    );
  }

  @override
  Future<Convite> convite(int clienteId) async =>
      Convite.fromJson(await http.send('POST', '/clientes/$clienteId/convite'));
  @override
  Future<ContaCriada> criarFuncionario(Map<String, dynamic> dados) async {
    if (!permiteCriarFuncionario) {
      throw const ApiException(
        'Cadastro de funcionário aguardando integração.',
      );
    }
    return ContaCriada.fromJson(
      await http.send('POST', '/auth/funcionarios', body: dados),
    );
  }

  @override
  Future<void> excluir(int id) async {
    await http.send('DELETE', '/usuarios/$id');
  }

  @override
  Future<void> restaurar(int id, String senha) async {
    await http.send('POST', '/usuarios/$id/restaurar', body: {'senha': senha});
  }
}
