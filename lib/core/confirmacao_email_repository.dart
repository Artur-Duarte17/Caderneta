import 'http_gateway.dart';

abstract interface class ConfirmacaoEmailRepository {
  Future<String> solicitar(String email);
  Future<void> confirmar(int? lojaId, String token);
}

class HttpConfirmacaoEmailRepository implements ConfirmacaoEmailRepository {
  HttpConfirmacaoEmailRepository(this.http);
  final HttpGateway http;

  @override
  Future<String> solicitar(String email) async {
    final dados = await http.send(
      'POST',
      '/auth/email/solicitar',
      body: {'email': email},
    );
    return dados['message'] as String;
  }

  @override
  Future<void> confirmar(int? lojaId, String token) => http.send(
    'POST',
    '/auth/email/confirmar',
    autenticado: false,
    body: {'lojaId': lojaId, 'token': token},
  );
}
