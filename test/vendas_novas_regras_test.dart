import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:caderneta/core/format.dart';
import 'package:caderneta/core/http_gateway.dart';
import 'app_test.dart' show abrir, fechar;

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  test(
    'valores são convertidos em centavos sem arredondar entrada inválida',
    () {
      expect(parseCentavos('1.234,56'), 123456);
      expect(parseCentavos('100'), 10000);
      expect(parseCentavos('100.01'), 10001);
      for (final valor in ['NaN', 'Infinity', '1,001', '-1', '10000000000']) {
        expect(parseCentavos(valor), isNull);
      }
    },
  );
  testWidgets('conteúdo autenticado começa no topo esquerdo', (tester) async {
    await abrir(tester, perfil: 'GERENTE', path: '/vendas', width: 1280);
    final pos = tester.getTopLeft(find.text('Vendas a prazo'));
    expect(pos.dy, lessThan(40));
    expect(pos.dx, inInclusiveRange(260, 300));
    await fechar(tester);
  });
  testWidgets('cadastro rápido não abre item obrigatório', (tester) async {
    await abrir(tester, perfil: 'FUNCIONARIO', path: '/vendas', width: 390);
    await tester.ensureVisible(find.text('Nova venda'));
    await tester.tap(find.text('Nova venda'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Valor total *'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Descrição *'), findsNothing);
    expect(find.text('Valor não detalhado'), findsOneWidget);
    await tester.ensureVisible(find.text('Adicionar item'));
    await tester.tap(find.text('Adicionar item'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Descrição *'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await fechar(tester);
  });
  test(
    'timeout conserva chave e uma operação confirmada permite nova venda igual',
    () async {
      final chaves = <String>[];
      final gateway = HttpGateway(
        timeout: const Duration(milliseconds: 20),
        client: MockClient((req) async {
          if (req.url.path.endsWith('/csrf')) {
            return http.Response(
              jsonEncode({'token': 'x', 'headerName': 'X-CSRF-TOKEN'}),
              200,
            );
          }
          chaves.add(req.headers['Idempotency-Key']!);
          if (chaves.length == 1) return Completer<http.Response>().future;
          return http.Response('{}', 200);
        }),
      );
      addTearDown(gateway.dispose);
      final body = {'clienteId': 20, 'valorTotal': 100, 'itens': []};
      await expectLater(
        gateway.send('POST', '/vendas', body: body),
        throwsA(isA<Exception>()),
      );
      expect(chaves.length, 1);
      await gateway.send('POST', '/vendas', body: body);
      expect(chaves[0], chaves[1]);
      await gateway.send('POST', '/vendas', body: body);
      expect(chaves[2], isNot(chaves[1]));
    },
  );
}
