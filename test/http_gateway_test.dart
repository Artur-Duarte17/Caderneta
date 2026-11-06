import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:caderneta/core/api_error.dart';
import 'package:caderneta/core/csrf.dart';
import 'package:caderneta/core/http_gateway.dart';
import 'package:caderneta/core/api.dart' show Api;
import 'package:caderneta/core/models.dart' show ItemVenda;

http.Response json(dynamic value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);
void main() {
  test(
    'venda não envia responsável do navegador e edição preserva data legada',
    () async {
      final corpos = <Map<String, dynamic>>[];
      final gateway = HttpGateway(
        client: MockClient((req) async {
          if (req.url.path.endsWith('/csrf')) {
            return json({'token': 'x', 'headerName': 'X-CSRF-TOKEN'});
          }
          corpos.add(jsonDecode(req.body));
          return json({});
        }),
      );
      addTearDown(gateway.dispose);
      final api = Api(gateway: gateway);
      await api.criarVenda(20, [
        ItemVenda(descricao: 'Produto', quantidade: 2, precoUnitario: 3),
      ], valorTotal: 6);
      await api.atualizarVenda(
        1,
        clienteId: 20,
        valorTotal: 6,
        versao: 0,
        itens: const [],
        data: DateTime(2026, 11, 5),
      );
      expect(corpos.every((c) => !c.containsKey('funcionarioId')), true);
      expect(
        corpos[1]['dataHora'],
        DateTime(2026, 11, 5).toUtc().toIso8601String(),
      );
    },
  );
  test('timeout cobre envio pendente e não repete mutação', () async {
    var mutacoes = 0;
    final pendente = Completer<http.Response>();
    final gateway = HttpGateway(
      timeout: const Duration(milliseconds: 5),
      client: MockClient((req) async {
        if (req.url.path.endsWith('/csrf')) {
          return json({'token': 'x', 'headerName': 'X-CSRF-TOKEN'});
        }
        mutacoes++;
        return pendente.future;
      }),
    );
    addTearDown(gateway.dispose);
    await expectLater(
      gateway.send('POST', '/vendas', body: {}),
      throwsA(isA<SemConexao>()),
    );
    expect(mutacoes, 1);
    pendente.complete(json({}));
  });
  test(
    'base relativa, host, barra final e prefixo api não duplicam caminho',
    () {
      for (final base in [
        '',
        'http://localhost:8080',
        'http://localhost:8080/',
        'http://localhost:8080/api/',
      ]) {
        final uri = apiUri(base, '/api/clientes', {'page': '0'});
        expect(uri.path, '/api/clientes');
        expect(uri.queryParameters, {'page': '0'});
      }
    },
  );
  test(
    'CSRF deduplica busca concorrente e não reaproveita token invalidado',
    () async {
      var chamadas = 0;
      final c = Completer<dynamic>();
      final store = CsrfStore(() {
        chamadas++;
        return c.future;
      });
      final a = store.obter(), b = store.obter();
      expect(chamadas, 1);
      c.complete({'token': 'um', 'headerName': 'X-CSRF-TOKEN'});
      expect((await a).token, 'um');
      expect((await b).token, 'um');
      await store.obter();
      expect(chamadas, 1);
      store.limpar();
      await store.obter();
      expect(chamadas, 2);
    },
  );
  test(
    'GET não envia CSRF; todos os mutadores usam header informado',
    () async {
      final vistos = <http.Request>[];
      final gateway = HttpGateway(
        client: MockClient((req) async {
          vistos.add(req);
          return req.url.path.endsWith('/csrf')
              ? json({'token': 'valor', 'headerName': 'X-PROJETO-CSRF'})
              : json({});
        }),
      );
      addTearDown(gateway.dispose);
      await gateway.send('GET', '/clientes');
      for (final method in ['POST', 'PUT', 'PATCH', 'DELETE']) {
        await gateway.send(method, '/clientes', body: {'nome': 'Teste'});
      }
      expect(vistos.first.headers.containsKey('X-PROJETO-CSRF'), false);
      expect(vistos.where((r) => r.url.path.endsWith('/csrf')).length, 1);
      for (final r in vistos.where((r) => r.method != 'GET')) {
        expect(r.headers['X-PROJETO-CSRF'], 'valor');
      }
    },
  );
  test('CSRF_INVALID renova uma vez e nunca repete uma venda', () async {
    var csrf = 0, vendas = 0;
    final gateway = HttpGateway(
      client: MockClient((req) async {
        if (req.url.path.endsWith('/csrf')) {
          csrf++;
          return json({'token': '$csrf', 'headerName': 'X-CSRF-TOKEN'});
        }
        vendas++;
        return json({'code': 'CSRF_INVALID'}, 403);
      }),
    );
    addTearDown(gateway.dispose);
    await expectLater(
      gateway.send('POST', '/vendas', body: {}),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'CSRF_INVALID'),
      ),
    );
    expect(vendas, 1);
    expect(csrf, 2);
  });
  test(
    'resposta de época anterior é descartada antes de expirar nova conta',
    () async {
      final response = Completer<http.Response>();
      var epoca = 1, expiracoes = 0;
      final gateway = HttpGateway(client: MockClient((_) => response.future));
      // Atribuições separadas tornam explícita a captura da época de cada pedido.
      gateway.epoca = () => epoca;
      gateway.aoExpirar = () {
        expiracoes++;
      };
      addTearDown(gateway.dispose);
      final request = gateway.send('GET', '/clientes');
      final check = expectLater(request, throwsA(isA<RespostaDescartada>()));
      epoca++;
      response.complete(json({}, 401));
      await check;
      expect(expiracoes, 0);
    },
  );
  for (final status in [400, 401, 403, 404, 409, 429, 500, 502, 504]) {
    test('erro $status é tratado e HTML não chega à tela', () async {
      final gateway = HttpGateway(
        client: MockClient(
          (_) async => http.Response('<html>segredo interno</html>', status),
        ),
      );
      addTearDown(gateway.dispose);
      await expectLater(
        gateway.send('GET', '/clientes'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', status)
              .having((e) => e.message.contains('<html>'), 'sem HTML', false),
        ),
      );
    });
  }
  test('401 no login é genérico mesmo quando servidor detalha conta', () async {
    final e = erroApi(401, {'message': 'usuário inexistente'}, login: true);
    expect(e.message, 'Login ou senha inválidos.');
    expect(
      erroApi(404, {'message': 'cliente alheio existe'}).message,
      'Recurso não encontrado.',
    );
    expect(
      erroApi(409, {'message': 'Saldo incompatível'}).message,
      'Saldo incompatível',
    );
  });
  test('falha de rede tem mensagem apropriada', () async {
    final gateway = HttpGateway(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    addTearDown(gateway.dispose);
    await expectLater(
      gateway.send('GET', '/clientes'),
      throwsA(isA<SemConexao>()),
    );
  });
}
