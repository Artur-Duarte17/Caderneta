import 'package:caderneta/widgets/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app_test.dart' show abrir, fechar;

String _rotaAtual(WidgetTester tester) => GoRouter.of(
  tester.element(find.byType(AppShell)),
).routeInformationProvider.value.uri.toString();

Future<void> _entrar(WidgetTester tester, String login) async {
  await tester.enterText(find.byType(TextFormField).at(0), login);
  await tester.enterText(find.byType(TextFormField).at(1), 'qualquer');
  await tester.tap(find.text('Entrar'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets(
    'sair no Histórico e entrar com outro usuário abre a Visão Geral',
    (tester) async {
      await abrir(tester, perfil: 'GERENTE', path: '/historico');
      expect(find.text('Histórico'), findsWidgets);

      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();
      expect(find.text('Entrar'), findsOneWidget);

      await _entrar(tester, 'funcionario');
      expect(_rotaAtual(tester), '/');
      expect(find.text('Visão Geral'), findsWidgets);
      await fechar(tester);
    },
  );

  testWidgets('o mesmo usuário também recomeça na Visão Geral', (tester) async {
    await abrir(tester, perfil: 'GERENTE', path: '/auditoria');
    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();
    await _entrar(tester, 'gerente');
    expect(_rotaAtual(tester), '/');
    await fechar(tester);
  });

  testWidgets('cliente entra sempre na própria tela inicial', (tester) async {
    await abrir(tester, perfil: 'GERENTE', path: '/clientes');
    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();
    await _entrar(tester, 'cliente.a');
    expect(_rotaAtual(tester), '/minha');
    await fechar(tester);
  });
}
