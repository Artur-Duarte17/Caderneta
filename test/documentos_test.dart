import 'package:caderneta/core/documentos.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

TextEditingValue _digitar(
  TextInputFormatter f,
  String antes,
  String depois, {
  int? cursor,
}) => f.formatEditUpdate(
  TextEditingValue(text: antes),
  TextEditingValue(
    text: depois,
    selection: TextSelection.collapsed(offset: cursor ?? depois.length),
  ),
);

void main() {
  group('CPF', () {
    test('regex aceita com ou sem máscara e recusa formatos quebrados', () {
      for (final ok in ['52998224725', '529.982.247-25', '529982247-25']) {
        expect(cpfRegex.hasMatch(ok), true, reason: ok);
      }
      for (final ruim in [
        '5299822472',
        '529.982.247-2',
        '529 982 247 25',
        'abc.def.ghi-jk',
        '529.982.247-255',
      ]) {
        expect(cpfRegex.hasMatch(ruim), false, reason: ruim);
      }
    });

    test('valida dígitos verificadores', () {
      expect(cpfValido('529.982.247-25'), true);
      expect(cpfValido(' 52998224725 '), true);
      expect(cpfValido('529.982.247-26'), false);
      expect(cpfValido('111.111.111-11'), false);
      expect(cpfValido(''), false);
    });

    test('formata e exibe', () {
      expect(formatarCpf('52998224725'), '529.982.247-25');
      expect(formatarCpf('5299'), '529.9');
      expect(formatarCpf('529982'), '529.982');
      expect(formatarCpf('5299822'), '529.982.2');
      expect(formatarCpf('5299822472'), '529.982.247-2');
      expect(exibirCpf('52998224725'), '529.982.247-25');
      expect(exibirCpf('529.982.247-25'), '529.982.247-25');
      expect(exibirCpf(null), '—');
      expect(exibirCpf('', vazio: 'Não informado'), 'Não informado');
      expect(
        exibirCpf('123'),
        '123',
        reason: 'valor legado inválido aparece como foi gravado',
      );
    });
  });

  group('Telefone', () {
    test('aceita celular e fixo com DDD, com ou sem máscara', () {
      for (final ok in [
        '64999991234',
        '(64) 99999-1234',
        '+55 64 99999-1234'.substring(4), // sem o 55
        '1133334444',
        '(11) 3333-4444',
        '(21) 5555-0000',
      ]) {
        expect(telefoneValido(ok), true, reason: ok);
      }
    });

    test(
      'recusa sem DDD, DDD inválido, celular sem 9 e fixo começando em 6–9',
      () {
        for (final ruim in [
          '99999-1234', // sem DDD
          '0199999-1234', // DDD com zero
          '(64) 89999-1234', // 11 dígitos sem o 9
          '(64) 6999-1234', // fixo começando em 6
          '5564999991234', // com DDI: o campo é só nacional
          '',
          null,
        ]) {
          expect(telefoneValido(ruim), false, reason: '$ruim');
        }
      },
    );

    test('formata e exibe', () {
      expect(formatarTelefone('64999991234'), '(64) 99999-1234');
      expect(formatarTelefone('1133334444'), '(11) 3333-4444');
      expect(formatarTelefone('6'), '(6');
      expect(formatarTelefone('649'), '(64) 9');
      expect(formatarTelefone('6499999'), '(64) 9999-9');
      expect(exibirTelefone('(64) 99999-1234'), '(64) 99999-1234');
      expect(exibirTelefone('64 9 9999 1234'), '(64) 99999-1234');
      expect(
        exibirTelefone('99991234'),
        '99991234',
        reason: 'legado sem DDD fica como está',
      );
      expect(exibirTelefone(null), '—');
    });
  });

  group('Máscara de digitação', () {
    test('CPF: aplica a máscara, descarta letras e limita a 11 dígitos', () {
      final f = MascaraInputFormatter.cpf();
      expect(_digitar(f, '', '52998224725').text, '529.982.247-25');
      expect(_digitar(f, '', '529a98').text, '529.98');
      expect(
        _digitar(f, '529.982.247-25', '529.982.247-251').text,
        '529.982.247-25',
      );
    });

    test('telefone: aplica a máscara ao colar e ao digitar', () {
      final f = MascaraInputFormatter.telefone();
      expect(_digitar(f, '', '64999991234').text, '(64) 99999-1234');
      expect(_digitar(f, '', '(64) 3333-4444').text, '(64) 3333-4444');
      final v = _digitar(f, '(64', '(649');
      expect(v.text, '(64) 9');
      expect(v.selection.baseOffset, v.text.length);
    });

    test('editar no meio mantém o cursor depois do mesmo dígito', () {
      final f = MascaraInputFormatter.cpf();
      // Apaga o "9" de "529.982..." (cursor depois do "52").
      final v = _digitar(f, '529.982.247-25', '52.982.247-25', cursor: 2);
      expect(v.text, '529.822.472-5');
      expect(v.selection.baseOffset, 2);
    });
  });
}
