import 'package:caderneta/core/validacoes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app_test.dart' show abrir, fechar;

String _digitar(List<TextInputFormatter> fs, String texto) {
  var v = TextEditingValue(
    text: texto,
    selection: TextSelection.collapsed(offset: texto.length),
  );
  for (final f in fs) {
    v = f.formatEditUpdate(TextEditingValue.empty, v);
  }
  return v.text;
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('Nome', () {
    test('aceita nomes reais', () {
      for (final ok in [
        'Maria da Silva',
        'José',
        "D'Ávila Souza",
        'Ana-Maria Conceição',
        'João Jr.',
        'A. B. Pereira',
      ]) {
        expect(validarNome(ok), isNull, reason: ok);
      }
    });
    test('recusa vazio, curto, números e símbolos', () {
      expect(validarNome(''), 'Campo obrigatório');
      expect(validarNome('Al'), contains('3 letras'));
      for (final ruim in ['Maria 2', 'João@Silva', '---', 'Ana  -  ']) {
        expect(validarNome(ruim), isNotNull, reason: ruim);
      }
      expect(validarNome('x' * 151), contains('150'));
    });
    test('filtro descarta números/símbolos e espaços duplos', () {
      expect(_digitar(filtroNome, 'Maria2 da Silva!'), 'Maria da Silva');
      expect(_digitar(filtroNome, 'Ana  Clara'), 'Ana Clara');
      expect(_digitar(filtroNome, 'x' * 200).length, 150);
    });
  });

  group('E-mail', () {
    test('aceita formatos comuns', () {
      for (final ok in [
        'maria@gmail.com',
        'jose.silva+loja@empresa.com.br',
        'a_b-c@sub.dominio.org',
      ]) {
        expect(validarEmail(ok), isNull, reason: ok);
      }
      expect(validarEmail(''), isNull, reason: 'opcional');
      expect(validarEmail('', obrigatorio: true), 'Campo obrigatório');
    });
    test('recusa formatos inválidos', () {
      for (final ruim in [
        'invalido',
        'maria@',
        '@gmail.com',
        'maria@gmail',
        'maria@gmail.c',
        'maria..silva@gmail.com',
        'maria@-gmail.com',
        'maria silva@gmail.com',
      ]) {
        expect(validarEmail(ruim), isNotNull, reason: ruim);
      }
    });
    test('filtro remove espaços e limita a 100', () {
      expect(_digitar(filtroEmail, ' maria @gmail.com '), 'maria@gmail.com');
      expect(_digitar(filtroEmail, 'a' * 120).length, 100);
    });
  });

  test('endereço: opcional, mínimo e exige letras', () {
    expect(validarEndereco(''), isNull);
    expect(validarEndereco('Rua 1, 123 - Centro'), isNull);
    expect(validarEndereco('123'), isNotNull);
    expect(validarEndereco('12345, 67'), isNotNull);
    expect(_digitar(filtroEndereco, 'Rua\tA').contains('\t'), isFalse);
    expect(_digitar(filtroEndereco, 'x' * 250).length, 200);
  });

  test('descrição do item: obrigatória, com letra ou número, até 200', () {
    expect(validarDescricao('Arroz 5kg'), isNull);
    expect(validarDescricao('  '), 'Informe a descrição');
    expect(validarDescricao('---'), isNotNull);
    expect(_digitar(filtroDescricao, 'x' * 250).length, 200);
  });

  test('matrícula e cargo', () {
    expect(validarMatricula(''), isNull);
    expect(validarMatricula('2024-001/A'), isNull);
    expect(validarMatricula('-001'), isNotNull);
    expect(_digitar(filtroMatricula, 'MAT 12#3'), 'MAT123');
    expect(validarCargo('Caixa 2'), isNull);
    expect(validarCargo('Atendente/Vendas'), isNull);
    expect(validarCargo(''), 'Campo obrigatório');
    expect(_digitar(filtroCargo, 'Caixa @1'), 'Caixa 1');
  });

  test('login: criação só com caracteres aceitos; entrada só sem espaços', () {
    expect(_digitar(filtroLoginNovo, 'joão silva!'), 'joosilva');
    expect(_digitar(filtroLoginNovo, 'maria.s_2-x'), 'maria.s_2-x');
    expect(_digitar(filtroLoginEntrada, ' admin '), 'admin');
    expect(_digitar(filtroSenha, 'x' * 100).length, 72);
  });

  test('código do convite: maiúsculas, alfabeto do backend, 20 caracteres', () {
    expect(_digitar(filtroConvite, 'abcd-efgh_2345!'), 'ABCD-EFGH2345');
    expect(validarConvite('ABCDEFGHJKLMNPQRSTUV'), isNull);
    expect(validarConvite('abcd-efgh-jklm-npqr-stuv'), isNull);
    expect(validarConvite('ABCDEFGHJKLMNPQRSTU'), isNotNull, reason: '19');
    expect(validarConvite('ABCDEFGHIJKLMNOPQRST'), isNotNull, reason: 'I e O');
    expect(validarConvite('ABCDEFGHJKLMNPQRST01'), isNotNull, reason: '0 e 1');
    expect(validarConvite(''), 'Campo obrigatório');
  });

  test('filtro de auditoria vira código: "venda criada" -> VENDA_CRIADA', () {
    expect(_digitar(filtroCodigoAuditoria, 'venda criada'), 'VENDA_CRIADA');
    expect(_digitar(filtroCodigoAuditoria, 'cliente-1'), 'CLIENTE');
  });

  testWidgets('cadastro de cliente filtra nome e recusa e-mail inválido', (
    tester,
  ) async {
    await abrir(tester, perfil: 'GERENTE', path: '/clientes');
    await tester.tap(find.text('Novo cliente'));
    await tester.pumpAndSettle();
    final nome = find.widgetWithText(TextFormField, 'Nome completo *');
    await tester.enterText(nome, 'Maria 123 Silva');
    await tester.pump();
    expect(tester.widget<TextFormField>(nome).controller!.text, 'Maria Silva');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-mail'),
      'maria@gmail',
    );
    await tester.tap(find.text('Cadastrar'));
    await tester.pumpAndSettle();
    expect(find.text('Informe um e-mail válido'), findsOneWidget);
    await fechar(tester);
  });
}
