class ApiException implements Exception {
  const ApiException(this.message, {this.status, this.code});
  final String message;
  final int? status;
  final String? code;
  @override
  String toString() => message;
}

class RespostaDescartada extends ApiException {
  const RespostaDescartada() : super('A sessão mudou. Atualize a página.');
}

class SemConexao extends ApiException {
  const SemConexao() : super('Sem conexão. Tente novamente.');
}

class SessaoExpirada extends ApiException {
  const SessaoExpirada()
    : super('Sua sessão expirou. Entre novamente.', status: 401);
}

class CredenciaisInvalidas extends ApiException {
  const CredenciaisInvalidas()
    : super('Login ou senha inválidos.', status: 401);
}

class AcessoNegado extends ApiException {
  const AcessoNegado() : super('Acesso negado.', status: 403);
}

class CsrfInvalido extends ApiException {
  const CsrfInvalido()
    : super(
        'A validação de segurança expirou. Tente novamente.',
        status: 403,
        code: 'CSRF_INVALID',
      );
}

class ConflitoNegocio extends ApiException {
  const ConflitoNegocio(super.message, {super.code}) : super(status: 409);
}

class NaoEncontrado extends ApiException {
  const NaoEncontrado() : super('Recurso não encontrado.', status: 404);
}

class ValidacaoApi extends ApiException {
  const ValidacaoApi(super.message, {super.code}) : super(status: 400);
}

ApiException erroApi(int status, dynamic body, {bool login = false}) {
  final code = body is Map ? body['code'] as String? : null;
  final message = body is Map ? body['message'] as String? : null;
  if (status == 401) {
    return login ? const CredenciaisInvalidas() : const SessaoExpirada();
  }
  if (status == 403) {
    return code == 'CSRF_INVALID' ? const CsrfInvalido() : const AcessoNegado();
  }
  if (status == 404) return const NaoEncontrado();
  final fallback = switch (status) {
    400 => 'Confira os dados informados.',
    401 =>
      login
          ? 'Login ou senha inválidos.'
          : 'Sua sessão expirou. Entre novamente.',
    403 =>
      code == 'CSRF_INVALID'
          ? 'A validação de segurança expirou. Tente novamente.'
          : 'Acesso negado.',
    404 => 'Recurso não encontrado.',
    409 => 'Não foi possível concluir devido a um conflito.',
    429 => 'Muitas tentativas. Aguarde e tente novamente.',
    _ => 'Servidor indisponível. Tente novamente.',
  };
  // Somente mensagens de validação e negócio são apropriadas para exibição.
  final seguro =
      (status == 400 || status == 409) &&
          message != null &&
          !message.contains('<')
      ? message
      : fallback;
  if (status == 400) return ValidacaoApi(seguro, code: code);
  if (status == 409) return ConflitoNegocio(seguro, code: code);
  return ApiException(seguro, status: status, code: code);
}
