import 'dart:convert';

import 'package:caderneta/core/app_runtime.dart';
import 'package:caderneta/core/models.dart';
import 'package:caderneta/dev/fakes.dart';
import 'package:caderneta/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';

import 'app_test.dart' show fechar, user;

/// Responde o relatório de pagamentos com todos os métodos; o resto vai para
/// o servidor simulado.
class _ComTodosMetodos extends http.BaseClient {
  _ComTodosMetodos(this.destino);
  final http.Client destino;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method == 'GET' &&
        request.url.path.endsWith('/relatorios/pagamentos')) {
      final agora = DateTime.now().toUtc().toIso8601String();
      final corpo = jsonEncode([
        for (final (i, m) in MetodoPagamento.values.indexed)
          {
            'id': i + 1,
            'dividaId': 1,
            'valorPago': 100.0 * (i + 1),
            'dataPagamento': agora,
            'metodoPagamento': m.name,
          },
      ]);
      return http.StreamedResponse(
        Stream.value(utf8.encode(corpo)),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return destino.send(request);
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  for (final largura in [360.0, 1280.0]) {
    testWidgets(
      'recebimentos por método: nomes não se sobrepõem em ${largura.toInt()} px',
      (tester) async {
        tester.view.physicalSize = Size(largura, 2400);
        tester.view.devicePixelRatio = 1;
        final fake = ServidorSimulado(latencia: Duration.zero)
          ..usuario = user('GERENTE');
        await tester.pumpWidget(
          CadernetaApp(
            runtime: AppRuntime(
              client: _ComTodosMetodos(fake.client),
              simulado: true,
            ),
            initialLocation: '/relatorios',
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final grafico = find.byKey(const ValueKey('grafico-metodos'));
        expect(grafico, findsOneWidget);
        final caixas = <Rect>[];
        for (final m in MetodoPagamento.values) {
          final f = find.descendant(of: grafico, matching: find.text(m.label));
          expect(f, findsOneWidget, reason: m.label);
          caixas.add(tester.getRect(f));
        }
        for (var i = 0; i < caixas.length; i++) {
          for (var j = i + 1; j < caixas.length; j++) {
            expect(
              caixas[i].overlaps(caixas[j]),
              isFalse,
              reason: '${caixas[i]} x ${caixas[j]}',
            );
          }
        }
        // Maior valor primeiro (Boleto = 600).
        expect(caixas.last.top, lessThan(caixas.first.top));
        await fechar(tester);
      },
    );
  }
}
