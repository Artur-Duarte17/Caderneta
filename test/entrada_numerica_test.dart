import 'package:caderneta/core/entrada_numerica.dart';
import 'package:caderneta/core/format.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app_test.dart' show abrir, fechar;

String _aplicar(List<TextInputFormatter> fs, String antes, String depois) {
  var v = TextEditingValue(
    text: depois,
    selection: TextSelection.collapsed(offset: depois.length),
  );
  final velho = TextEditingValue(text: antes);
  for (final f in fs) {
    v = f.formatEditUpdate(velho, v);
  }
  return v.text;
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('somenteInteiro', () {
    test('descarta letras, sinais e separadores; limita dígitos', () {
      final f = somenteInteiro(maxDigitos: 4);
      expect(_aplicar(f, '', '12a3'), '123');
      expect(_aplicar(f, '', '-30'), '30');
      expect(_aplicar(f, '', '1,5'), '15');
      expect(_aplicar(f, '', 'abc'), '');
      expect(_aplicar(f, '', '123456'), '1234');
    });
  });

  group('ValorMonetarioInputFormatter', () {
    final f = somenteValorMonetario();

    test('aceita formatos de dinheiro válidos', () {
      for (final ok in [
        '',
        '0',
        '10',
        '10,',
        '10,5',
        '10,50',
        '1.234,56',
        '1234.56',
      ]) {
        expect(_aplicar(f, '', ok), ok, reason: ok);
      }
    });

    test('remove letras e símbolos, inclusive ao colar "R\$ 1.234,56"', () {
      expect(_aplicar(f, '', 'R\$ 1.234,56'), '1.234,56');
      expect(_aplicar(f, '', '12a'), '12');
      expect(_aplicar(f, '', 'abc'), '');
      expect(_aplicar(f, '', '-5'), '5');
    });

    test('recusa a edição que quebra o formato (mantém o valor anterior)', () {
      expect(_aplicar(f, '10,50', '10,505'), '10,50'); // 3 casas
      expect(_aplicar(f, '10,5', '10,5,'), '10,5'); // duas vírgulas
      expect(_aplicar(f, '', ',5'), ''); // começa com vírgula
      expect(_aplicar(f, '1', '12345678901234567'), '1'); // longo demais
    });

    test(
      'o que o filtro deixa passar continua compatível com parseCentavos',
      () {
        expect(parseCentavos(_aplicar(f, '', 'R\$ 1.234,56')), 123456);
        expect(parseCentavos(_aplicar(f, '', '10,5')), 1050);
        expect(parseCentavos(_aplicar(f, '', '1234.56')), 123456);
      },
    );
  });

  testWidgets('formulário de cliente não aceita letras em limite e prazo', (
    tester,
  ) async {
    await abrir(tester, perfil: 'GERENTE', path: '/clientes');
    await tester.tap(find.text('Novo cliente'));
    await tester.pumpAndSettle();
    final limite = find.widgetWithText(TextFormField, 'Limite de crédito');
    final prazo = find.widgetWithText(TextFormField, 'Prazo de pagamento');
    await tester.enterText(limite, 'abc');
    await tester.enterText(prazo, 'trinta');
    await tester.pump();
    String texto(Finder f) => tester.widget<TextFormField>(f).controller!.text;
    expect(texto(limite), '');
    expect(texto(prazo), '');
    await tester.enterText(limite, 'R\$ 150,75');
    await tester.enterText(prazo, '45 dias');
    await tester.pump();
    expect(texto(limite), '150,75');
    expect(texto(prazo), '45');
    await fechar(tester);
  });

  testWidgets(
    'nova venda não aceita letras em total, quantidade e valor unitário',
    (tester) async {
      await abrir(tester, perfil: 'GERENTE', path: '/vendas');
      await tester.tap(find.text('Nova venda'));
      await tester.pumpAndSettle();
      String texto(Finder f) =>
          tester.widget<TextFormField>(f).controller!.text;
      final total = find.widgetWithText(TextFormField, 'Valor total *');
      await tester.enterText(total, 'cem reais');
      await tester.pump();
      expect(texto(total), '');
      await tester.ensureVisible(find.text('Adicionar item'));
      await tester.tap(find.text('Adicionar item'));
      await tester.pumpAndSettle();
      final qtd = find.widgetWithText(TextFormField, 'Qtd *').first;
      final valor = find
          .widgetWithText(TextFormField, 'Valor unitário *')
          .first;
      await tester.enterText(qtd, '2x');
      await tester.enterText(valor, 'dez');
      await tester.pump();
      expect(texto(qtd), '2');
      expect(texto(valor), '');
      await tester.enterText(valor, '9,9a9');
      await tester.pump();
      expect(texto(valor), '9,99');
      await fechar(tester);
    },
  );
}
