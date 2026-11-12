import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app_test.dart' show abrir, fechar;

Future<void> _tocar(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('lojista cria a própria loja e entra nela como gerente', (
    tester,
  ) async {
    await abrir(tester, path: '/login');
    await _tocar(tester, find.text('Criar minha loja'));
    expect(find.text('Sua loja'.toUpperCase()), findsOneWidget);

    Future<void> campo(String rotulo, String valor) =>
        tester.enterText(find.widgetWithText(TextFormField, rotulo), valor);
    // Validação: senhas diferentes não enviam.
    await campo('Nome da loja *', 'Mercado São José');
    await campo('Seu nome *', 'José da Silva');
    await campo('CPF *', '52998224725');
    await campo('Login *', 'jose.mercado');
    await campo('Senha *', 'Senha-Loja-1');
    await campo('Confirmar senha *', 'outra-senha');
    await _tocar(tester, find.text('Criar loja'));
    expect(find.text('As senhas não coincidem'), findsOneWidget);

    await campo('Confirmar senha *', 'Senha-Loja-1');
    await _tocar(tester, find.text('Criar loja'));
    expect(
      find.textContaining('Loja "Mercado São José" criada'),
      findsOneWidget,
    );
    expect(find.text('Entrar'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'jose.mercado');
    await tester.enterText(find.byType(TextFormField).at(1), 'Senha-Loja-1');
    await _tocar(tester, find.text('Entrar'));
    expect(find.text('Mercado São José'), findsWidgets);
    expect(find.text('Visão Geral'), findsWidgets);
    await fechar(tester);
  });

  testWidgets('login já usado em outra loja é recusado', (tester) async {
    await abrir(tester, path: '/criar-loja');
    Future<void> campo(String rotulo, String valor) =>
        tester.enterText(find.widgetWithText(TextFormField, rotulo), valor);
    await campo('Nome da loja *', 'Loja Repetida');
    await campo('Seu nome *', 'Maria Souza');
    await campo('CPF *', '52998224725');
    await campo('Login *', 'gerente'); // já existe no simulador
    await campo('Senha *', 'Senha-Loja-1');
    await campo('Confirmar senha *', 'Senha-Loja-1');
    await _tocar(tester, find.text('Criar loja'));
    expect(find.textContaining('Login já em uso'), findsOneWidget);
    await fechar(tester);
  });
}
