import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app_test.dart' show abrir, fechar;

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('gerente torna funcionário gerente e depois volta', (
    tester,
  ) async {
    await abrir(tester, perfil: 'GERENTE', path: '/acessos');
    // Só contas da equipe têm a ação; clientes e a própria conta não.
    expect(find.text('Tornar gerente'), findsOneWidget);
    expect(find.text('Sua conta'), findsOneWidget);

    await tester.ensureVisible(find.text('Tornar gerente'));
    await tester.tap(find.text('Tornar gerente'));
    await tester.pumpAndSettle();
    expect(find.text('Tornar gerente?'), findsOneWidget);
    expect(find.textContaining('login e a senha continuam'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Tornar gerente'));
    await tester.pumpAndSettle();

    expect(find.textContaining('agora é gerente'), findsOneWidget);
    expect(find.text('Tornar gerente'), findsNothing);
    expect(find.text('Tornar funcionário'), findsOneWidget);

    // Com dois gerentes, rebaixar é permitido.
    await tester.ensureVisible(find.text('Tornar funcionário'));
    await tester.tap(find.text('Tornar funcionário'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Tornar funcionário'));
    await tester.pumpAndSettle();
    expect(find.textContaining('agora é funcionário'), findsOneWidget);
    expect(find.text('Tornar gerente'), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('funcionário não acessa a tela de acessos', (tester) async {
    await abrir(tester, perfil: 'FUNCIONARIO', path: '/acessos');
    expect(find.text('Tornar gerente'), findsNothing);
    expect(find.text('Acessos'), findsNothing);
    await fechar(tester);
  });
}
