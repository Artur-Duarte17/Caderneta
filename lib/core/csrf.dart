import 'api_error.dart';

class CsrfToken {
  const CsrfToken(this.token, this.headerName);
  final String token, headerName;
}

class CsrfStore {
  CsrfStore(this.carregar);
  final Future<dynamic> Function() carregar;
  CsrfToken? _token;
  Future<CsrfToken>? _pendente;
  int _geracao = 0;

  void limpar() {
    _geracao++;
    _token = null;
    _pendente = null;
  }

  Future<CsrfToken> obter() {
    if (_token != null) return Future.value(_token);
    return _pendente ??= _buscar(_geracao);
  }

  Future<CsrfToken> _buscar(int geracao) async {
    try {
      final json = await carregar();
      if (json is! Map ||
          json['token'] is! String ||
          (json['token'] as String).isEmpty ||
          json['headerName'] is! String ||
          (json['headerName'] as String).isEmpty) {
        throw const ApiException('Servidor indisponível. Tente novamente.');
      }
      final token = CsrfToken(json['token'], json['headerName']);
      if (geracao == _geracao) _token = token;
      return token;
    } finally {
      if (geracao == _geracao) _pendente = null;
    }
  }
}
