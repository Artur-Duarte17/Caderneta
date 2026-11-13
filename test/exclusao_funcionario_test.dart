import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app_test.dart' show abrir, fechar;

Future<void> _tocar(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _criarFuncionario(
  WidgetTester tester, {
  required String nome,
  required String login,
}) async {
  await _tocar(tester, find.text('Criar funcionário'));
  Future<void> campo(String rotulo, String valor) =>
      tester.enterText(find.widgetWithText(TextFormField, rotulo), valor);
  await campo('Nome *', nome);
  await campo('CPF *', '52998224725');
  await campo('Cargo *', 'Caixa');
  await campo('Login *', login);
  await campo('Senha *', 'Senha-Teste-1');
  await _tocar(tester, find.text('Criar acesso'));
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets(
    'excluir esconde, "Mostrar excluídos" exibe e restaurar pede senha nova',
    (tester) async {
      await abrir(tester, perfil: 'GERENTE', path: '/acessos');
      expect(find.text('Funcionário de exemplo'), findsOneWidget);

      await _tocar(tester, find.byTooltip('Excluir').first);
      expect(find.text('Excluir funcionário?'), findsOneWidget);
      expect(find.textContaining('Nada é apagado'), findsOneWidget);
      await _tocar(tester, find.widgetWithText(FilledButton, 'Excluir'));
      expect(find.textContaining('foi excluído'), findsOneWidget);
      expect(find.text('Funcionário de exemplo'), findsNothing);

      await _tocar(tester, find.text('Mostrar excluídos'));
      expect(find.text('Funcionário de exemplo'), findsOneWidget);
      expect(find.text('Excluído'), findsOneWidget);

      await _tocar(tester, find.text('Restaurar'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Senha nova *'),
        'curta',
      );
      await _tocar(tester, find.widgetWithText(FilledButton, 'Restaurar'));
      expect(
        find.text('A senha deve ter pelo menos 8 caracteres'),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Senha nova *'),
        'Senha-Nova-12',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmar senha *'),
        'Senha-Nova-12',
      );
      await _tocar(tester, find.widgetWithText(FilledButton, 'Restaurar'));
      expect(find.textContaining('foi restaurado'), findsOneWidget);
      expect(find.text('Excluído'), findsNothing);
      await fechar(tester);
    },
  );

  testWidgets('recadastrar o CPF de um excluído reativa a conta antiga', (
    tester,
  ) async {
    await abrir(tester, perfil: 'GERENTE', path: '/acessos');
    await _criarFuncionario(tester, nome: 'Davi Antigo', login: 'davi.antigo');
    expect(find.text('davi.antigo'), findsOneWidget);

    // Exclui o recém-criado (último da lista).
    await _tocar(tester, find.byTooltip('Excluir').last);
    await _tocar(tester, find.widgetWithText(FilledButton, 'Excluir'));
    expect(find.text('davi.antigo'), findsNothing);

    await _criarFuncionario(tester, nome: 'Davi Volta', login: 'outro.login');
    expect(find.text('Funcionário reativado'), findsOneWidget);
    expect(find.textContaining('Login: davi.antigo'), findsOneWidget);
    await _tocar(tester, find.text('Entendi'));
    expect(find.text('davi.antigo'), findsOneWidget);
    expect(find.text('outro.login'), findsNothing);
    await fechar(tester);
  });

  testWidgets('cliente não pode ser fiador de si mesmo', (tester) async {
    await abrir(tester, perfil: 'GERENTE', path: '/clientes');
    await _tocar(tester, find.text('Novo cliente'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'CPF *'),
      '52998224725',
    );
    await _tocar(tester, find.text('Cliente possui fiador'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'CPF do fiador *'),
      '52998224725',
    );
    await _tocar(tester, find.text('Cadastrar'));
    expect(
      find.text('O cliente não pode ser fiador de si mesmo'),
      findsOneWidget,
    );
    await fechar(tester);
  });
}
