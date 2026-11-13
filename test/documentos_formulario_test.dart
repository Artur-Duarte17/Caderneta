import 'dart:convert';

import 'package:caderneta/core/app_runtime.dart';
import 'package:caderneta/dev/fakes.dart';
import 'package:caderneta/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';

import 'app_test.dart' show fechar, user;

/// Repassa ao servidor simulado e guarda o corpo das requisições POST/PUT.
class _Captura extends http.BaseClient {
  _Captura(this.destino);
  final http.Client destino;
  final corpos = <String, Map<String, dynamic>>{};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request is http.Request && request.body.isNotEmpty) {
      corpos['${request.method} ${request.url.path}'] = jsonDecode(
        request.body,
      );
    }
    return destino.send(request);
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets(
    'cadastro de cliente: máscara na tela, só dígitos na API, telefone validado',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      final fake = ServidorSimulado(latencia: Duration.zero)
        ..usuario = user('GERENTE');
      final captura = _Captura(fake.client);
      await tester.pumpWidget(
        CadernetaApp(
          runtime: AppRuntime(client: captura, simulado: true),
          initialLocation: '/clientes',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Novo cliente'));
      await tester.pumpAndSettle();

      final telefone = find.widgetWithText(TextFormField, 'Telefone *');
      final cpf = find.widgetWithText(TextFormField, 'CPF *');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome completo *'),
        'Maria Teste',
      );
      await tester.enterText(cpf, '52998224725');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Limite de crédito *'),
        '100,00',
      );
      await tester.enterText(telefone, '99991234'); // sem DDD
      await tester.pumpAndSettle();
      expect(find.text('529.982.247-25'), findsOneWidget);

      await tester.tap(find.text('Cadastrar'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Informe um telefone com DDD'),
        findsOneWidget,
      );
      expect(captura.corpos.containsKey('POST /api/clientes'), isFalse);

      await tester.enterText(telefone, '64999991234');
      await tester.pumpAndSettle();
      expect(find.text('(64) 99999-1234'), findsOneWidget);
      await tester.tap(find.text('Cadastrar'));
      await tester.pumpAndSettle();

      final enviado = captura.corpos.entries
          .firstWhere(
            (e) => e.key.startsWith('POST') && e.key.endsWith('/clientes'),
          )
          .value;
      expect(enviado['cpf'], '52998224725');
      expect(enviado['telefone'], '64999991234');
      // A lista mostra o telefone formatado.
      expect(find.text('(64) 99999-1234'), findsWidgets);
      await fechar(tester);
    },
  );
}
