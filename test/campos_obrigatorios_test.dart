import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app_test.dart' show abrir, fechar;

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  for (final largura in [1280.0, 360.0]) {
    testWidgets(
      'criar funcionário marca obrigatórios (*) e opcionais em ${largura.toInt()} px',
      (tester) async {
        await abrir(
          tester,
          perfil: 'GERENTE',
          path: '/acessos',
          width: largura,
        );
        await tester.ensureVisible(find.text('Criar funcionário'));
        await tester.tap(find.text('Criar funcionário'));
        await tester.pumpAndSettle();
        expect(find.text('* Campos obrigatórios'), findsOneWidget);
        for (final r in ['Nome *', 'CPF *', 'Cargo *', 'Login *', 'Senha *']) {
          expect(
            find.widgetWithText(TextFormField, r),
            findsOneWidget,
            reason: r,
          );
        }
        for (final r in ['E-mail', 'Telefone', 'Endereço', 'Matrícula']) {
          expect(
            find.widgetWithText(TextFormField, r),
            findsOneWidget,
            reason: r,
          );
        }
        expect(find.text('opcional'), findsNWidgets(4));
        expect(tester.takeException(), isNull, reason: 'sem estouro de layout');
        await fechar(tester);
      },
    );
  }
}
