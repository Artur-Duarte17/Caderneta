import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:caderneta/core/format.dart';
import 'package:caderneta/dev/fakes.dart';
import 'app_test.dart' show abrir, fechar;

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  for (final rota in ['/clientes', '/vendas', '/pagamentos']) {
    testWidgets('busca conserva digitação, foco e permite limpar em $rota', (
      tester,
    ) async {
      await abrir(tester, perfil: 'GERENTE', path: rota);
      final campo = find.byType(TextField).first;
      await tester.tap(campo);
      for (final texto in ['C', 'Cl', 'Cliente']) {
        await tester.enterText(campo, texto);
        await tester.pumpAndSettle();
        final editavel = tester.widget<EditableText>(
          find.descendant(of: campo, matching: find.byType(EditableText)),
        );
        expect(editavel.controller.text, texto);
        expect(editavel.focusNode.hasFocus, isTrue);
      }
      await tester.tap(find.byTooltip('Limpar busca'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(campo).controller!.text, isEmpty);
      expect(find.byTooltip('Limpar busca'), findsNothing);
      await fechar(tester);
    });
  }

  testWidgets(
    'cadastro valida email e mantém erro do servidor dentro do diálogo',
    (tester) async {
      final fake = ServidorSimulado(latencia: Duration.zero);
      await abrir(tester, perfil: 'GERENTE', path: '/clientes', servidor: fake);
      await tester.tap(find.text('Novo cliente'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'CPF *'), findsOneWidget);
      expect(find.text('CPF/CNPJ *'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome completo *'),
        'Cliente de teste',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Telefone *'),
        '11999999999',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'CPF *'),
        '52998224725',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Limite de crédito'),
        '100,00',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-mail'),
        'invalido',
      );
      await tester.tap(find.text('Cadastrar'));
      await tester.pumpAndSettle();
      expect(find.text('Informe um e-mail válido'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-mail'),
        'teste@example.com',
      );
      fake.falhas['/clientes'] = 400;
      await tester.tap(find.text('Cadastrar'));
      await tester.pumpAndSettle();
      final dialogo = find.byType(AlertDialog);
      final anuncios = find.descendant(
        of: dialogo,
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.liveRegion == true,
        ),
      );
      expect(anuncios, findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Nome completo *'),
            )
            .controller!
            .text,
        'Cliente de teste',
      );
      await tester.pump(const Duration(seconds: 8));
      expect(anuncios, findsOneWidget);
      await fechar(tester);
    },
  );

  test(
    'eventos antigos e novos têm moeda pt-BR sem modificar mensagens livres',
    () {
      expect(
        mensagemFinanceira(r'Nova compra de R$ 10.00 (Venda #57)'),
        r'Nova compra de R$ 10,00 (Venda #57)',
      );
      expect(
        mensagemFinanceira(r'Pagamento de R$ 1 recebido para a dívida #48'),
        r'Pagamento de R$ 1,00 recebido para a dívida #48',
      );
      expect(
        mensagemFinanceira(r'Nova compra de R$ 1234.56 (Venda #57)'),
        r'Nova compra de R$ 1.234,56 (Venda #57)',
      );
      for (final mensagem in [
        r'Nova compra de R$ 10,00 (Venda #57)',
        r'Nova compra de R$ 1.234,56 (Venda #57)',
        r'Texto livre R$ 10.00',
      ]) {
        expect(mensagemFinanceira(mensagem), mensagem);
      }
      expect(
        mensagemFinanceira(
          r'Lembrete: sua dívida #1, com saldo de R$ 10.00, venceu em 2026-11-06.',
        ),
        r'Lembrete: sua dívida #1, com saldo de R$ 10,00, venceu em 2026-11-06.',
      );
    },
  );
}
