import 'http_gateway.dart';
import 'models.dart';

abstract interface class AuthRepository {
  Future<void> renovarCsrf();
  Future<Usuario> me();
  Future<Usuario> login(String login, String senha);
  Future<void> logout();
  Future<void> ativar(Map<String, dynamic> dados);
}

class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository(this.http);
  final HttpGateway http;
  @override
  Future<void> renovarCsrf() async {
    http.csrf.limpar();
    await http.csrf.obter();
  }

  @override
  Future<Usuario> me() async {
    final json = await http.send('GET', '/auth/me', autenticado: false);
    return Usuario.fromJson(json['usuario'] ?? json);
  }

  @override
  Future<Usuario> login(String login, String senha) async {
    final json = await http.send(
      'POST',
      '/auth/login',
      body: {'login': login, 'senha': senha},
      autenticado: false,
    );
    return Usuario.fromJson(json['usuario'] ?? json);
  }

  @override
  Future<void> logout() async {
    await http.send('POST', '/auth/logout', autenticado: false);
  }

  @override
  Future<void> ativar(Map<String, dynamic> dados) async {
    await http.send(
      'POST',
      '/auth/registro-cliente',
      body: dados,
      autenticado: false,
    );
  }
}
