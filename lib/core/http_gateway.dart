import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_error.dart';
import 'csrf.dart';
import 'idempotencia.dart';
import 'http_client_factory.dart';

const apiBaseUrl = String.fromEnvironment('API_URL', defaultValue: '');

Uri apiUri(String base, String path, [Map<String, String>? query]) {
  var prefix = base.replaceAll(RegExp(r'/+$'), '');
  if (prefix.endsWith('/api')) prefix = prefix.substring(0, prefix.length - 4);
  final suffix = path.startsWith('/api/') ? path.substring(4) : path;
  return Uri.parse(
    '$prefix/api${suffix.startsWith('/') ? suffix : '/$suffix'}',
  ).replace(queryParameters: query == null || query.isEmpty ? null : query);
}

class HttpGateway {
  HttpGateway({
    http.Client? client,
    this.base = apiBaseUrl,
    this.timeout = const Duration(seconds: 20),
  }) : client = client ?? criarHttpClient() {
    csrf = CsrfStore(
      () => send(
        'GET',
        '/auth/csrf',
        autenticado: false,
        query: {'_': '${DateTime.now().microsecondsSinceEpoch}'},
      ),
    );
  }
  final http.Client client;
  final String base;
  final Duration timeout;
  late final CsrfStore csrf;
  int Function() epoca = () => 0;
  int? Function() usuarioId = () => null;
  void Function()? aoExpirar;
  Future<void> Function()? verificarSessao;

  Future<http.Response> _enviar(http.Request req) async =>
      http.Response.fromStream(await client.send(req));

  Future<dynamic> send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    Map<String, String>? headers,
    bool autenticado = true,
  }) async {
    final inicio = epoca();
    void conferir() {
      if (inicio != epoca()) throw const RespostaDescartada();
    }

    final idempotente =
        method == 'POST' &&
        (path == '/vendas' ||
            RegExp(r'^/dividas/\d+/pagamentos$').hasMatch(path));
    final identidade = '${usuarioId()}:$method:$path:${jsonEncode(body)}';
    final req = http.Request(method, apiUri(base, path, query))
      ..headers.addAll({'Accept': 'application/json', ...?headers});
    if (idempotente) req.headers['Idempotency-Key'] = chaveOperacao(identidade);
    if (!const ['GET', 'HEAD', 'OPTIONS'].contains(method)) {
      final token = await csrf.obter();
      conferir();
      req.headers[token.headerName] = token.token;
    }
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    final http.Response response;
    try {
      response = await _enviar(req).timeout(timeout);
    } on TimeoutException {
      conferir();
      throw const SemConexao();
    } on http.ClientException {
      conferir();
      throw const SemConexao();
    }
    conferir();
    dynamic json;
    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (text.isNotEmpty) {
      try {
        json = jsonDecode(text);
      } on FormatException {
        json = null;
      }
    }
    if (response.statusCode >= 400) {
      if (response.statusCode == 401 && autenticado) aoExpirar?.call();
      final error = erroApi(
        response.statusCode,
        json,
        login: path == '/auth/login',
      );
      if (error.code == 'CSRF_INVALID') {
        csrf.limpar();
        try {
          await csrf.obter();
          if (autenticado) await verificarSessao?.call();
        } catch (_) {
          /* A mutação nunca é repetida. */
        }
        conferir();
      }
      throw error;
    }
    if (text.isNotEmpty && json == null) {
      throw const ApiException('Servidor indisponível. Tente novamente.');
    }
    if (idempotente) concluirOperacao(identidade);
    return json;
  }

  void dispose() => client.close();
}
