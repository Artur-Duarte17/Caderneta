import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caderneta/core/dados_relatorio.dart';
import 'package:caderneta/core/entrada_numerica.dart';
import 'package:caderneta/core/models.dart';
import 'package:caderneta/core/validacoes.dart';
import 'package:caderneta/dev/fakes.dart';
import 'package:caderneta/widgets/campo_senha.dart';
import 'package:caderneta/widgets/busca_sugestoes.dart';
import 'package:caderneta/widgets/common.dart';
import 'package:caderneta/widgets/detalhes_auditoria.dart';
import 'app_test.dart' show abrir, fechar, user;

void main() {
  testWidgets(
    'sugestões resistem a mudança de cursor durante consulta e selecionam por teclado',
    (t) async {
      final texto = TextEditingController();
      String? escolhido;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: BuscaSugestoes<String>(
                label: 'Cliente',
                controller: texto,
                texto: (v) => v,
                buscar: (q) async => ['Cliente Verificacao'],
                onSelecionar: (v) => escolhido = v,
              ),
            ),
          ),
        ),
      );
      await t.tap(find.byType(TextFormField));
      await t.enterText(find.byType(TextFormField), 'Cliente');
      texto.selection = const TextSelection.collapsed(offset: 3);
      await t.pump(const Duration(milliseconds: 350));
      await t.pumpAndSettle();
      expect(find.text('Cliente Verificacao'), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();
      expect(escolhido, 'Cliente Verificacao');
      await t.pumpWidget(const SizedBox());
      texto.dispose();
    },
  );
  testWidgets(
    'confirmar e-mail atualiza sessão e abre operação após reconstrução',
    (t) async {
      final fake = ServidorSimulado(latencia: Duration.zero)
        ..usuario = {...user('GERENTE'), 'emailConfirmado': false};
      await abrir(
        t,
        servidor: fake,
        path: '/confirmar-email#loja=1&token=${'f' * 64}',
      );
      await t.tap(find.text('Confirmar e-mail'));
      await t.pumpAndSettle();
      expect(find.text('Confirme o e-mail da loja'), findsNothing);
      expect(find.text('Visão Geral'), findsWidgets);
      await fechar(t);
    },
  );
  testWidgets('busca agrupa digitação e limpar cancela consulta pendente', (
    t,
  ) async {
    final pedidos = <String>[];
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchField(hint: 'Buscar', onChanged: pedidos.add),
        ),
      ),
    );
    await t.enterText(find.byType(TextField), 'M');
    await t.pump(const Duration(milliseconds: 100));
    await t.enterText(find.byType(TextField), 'Maria');
    await t.pump(const Duration(milliseconds: 299));
    expect(pedidos, isEmpty);
    await t.pump(const Duration(milliseconds: 1));
    expect(pedidos, ['Maria']);
    await t.enterText(find.byType(TextField), 'Carlos');
    await t.tap(find.byTooltip('Limpar busca'));
    await t.pump(const Duration(milliseconds: 400));
    expect(pedidos, ['Maria', '']);
  });
  test('apagar início de valor não trava estado intermediário', () {
    final antes = TextEditingValue(
      text: '6,66',
      selection: TextSelection.collapsed(offset: 1),
    );
    final depois = TextEditingValue(
      text: ',66',
      selection: TextSelection.collapsed(offset: 0),
    );
    expect(
      ValorMonetarioInputFormatter().formatEditUpdate(antes, depois),
      depois,
    );
  });
  testWidgets(
    'senha mantém texto e seleção; confirmação reage à senha original',
    (t) async {
      final senha = TextEditingController(),
          confirmar = TextEditingController();
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              child: Column(
                children: [
                  CampoSenha(controller: senha),
                  CampoSenha(
                    controller: confirmar,
                    confirmar: senha,
                    label: 'Confirmar senha *',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await t.enterText(find.byType(TextFormField).first, 'Senha-Nova-123');
      await t.enterText(find.byType(TextFormField).last, 'Senha-Nova-123');
      await t.pump();
      expect(find.text('As senhas não coincidem'), findsNothing);
      await t.enterText(find.byType(TextFormField).first, 'Senha-Outra-123');
      await t.pump();
      expect(find.text('As senhas não coincidem'), findsOneWidget);
      senha.selection = const TextSelection.collapsed(offset: 4);
      await t.tap(find.byTooltip('Mostrar senha'));
      await t.pump();
      expect(senha.text, 'Senha-Outra-123');
      expect(senha.selection.baseOffset, 4);
      await t.pumpWidget(const SizedBox());
      senha.dispose();
      confirmar.dispose();
    },
  );
  test('senhas comuns recusadas e frase válida aceita', () {
    expect(validarSenha('12345678'), isNotNull);
    expect(validarSenha('minha frase particular longa'), isNull);
  });
  test('relatório mantém totais, nomes e status ao usar índices', () {
    final vendas = [
      Venda(
        id: 1,
        clienteId: 7,
        valorTotal: 25,
        dividaId: 10,
        clienteNome: 'Maria',
      ),
      Venda(
        id: 2,
        clienteId: 7,
        valorTotal: 15,
        statusDivida: 'PAGA_TOTALMENTE',
      ),
    ];
    final r = DadosRelatorio(
      vendas,
      [
        Divida(
          id: 10,
          clienteId: 7,
          valorOriginal: 25,
          valorPendente: 25,
          statusBackend: 'ABERTA',
        ),
      ],
      [],
      [],
      {},
    );
    expect(r.nome(7), 'Maria');
    expect(r.nome(99), 'Cliente #99');
    expect(r.totalCliente(7), 40);
    expect(r.totalCliente(99), 0);
    expect(r.statusVenda(vendas.first), Status.pendente);
    expect(r.statusVenda(vendas.last), Status.pago);
  });
  testWidgets(
    'auditoria mostra antes/depois e remove segredos no JSON embutido',
    (t) async {
      await t.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DetalhesAuditoria({
              'acao': 'CLIENTE_EDITADO',
              'alteracoes':
                  '{"nome":{"antes":"Maria","depois":"Maria Silva"},"senha":{"antes":"segredo antigo","depois":"segredo novo"}}',
            }),
          ),
        ),
      );
      expect(find.text('Maria'), findsOneWidget);
      expect(find.text('Maria Silva'), findsOneWidget);
      expect(find.textContaining('segredo'), findsNothing);
    },
  );
  testWidgets('loja pendente vai à confirmação e não constrói operação', (
    t,
  ) async {
    final fake = ServidorSimulado(latencia: Duration.zero)
      ..usuario = {...user('GERENTE'), 'emailConfirmado': false};
    await abrir(t, servidor: fake, path: '/clientes');
    expect(find.text('Confirme o e-mail da loja'), findsOneWidget);
    expect(find.text('Novo cliente'), findsNothing);
    await fechar(t);
  });
  testWidgets('confirmação de e-mail mantém campo espaçado e cartão responsivo', (
    t,
  ) async {
    const descricao =
        'A loja só poderá ser utilizada depois da confirmação. Confira também a pasta de spam.';
    for (final width in [360.0, 1190.0]) {
      final fake = ServidorSimulado(latencia: Duration.zero)
        ..usuario = {...user('GERENTE'), 'emailConfirmado': false};
      await abrir(t, servidor: fake, path: '/confirmar-email', width: width);

      final cartao = t.getRect(find.byType(Card));
      expect(
        cartao.width,
        lessThanOrEqualTo(width < 528 ? width - 48 : 480),
        reason: 'cartão em $width px',
      );
      await t.tap(find.byType(TextField));
      await t.pumpAndSettle();
      expect(
        t.getRect(find.text('E-mail da loja')).top,
        greaterThan(t.getRect(find.text(descricao)).bottom),
        reason: 'rótulo flutuante em $width px',
      );
      expect(t.takeException(), isNull);
      await fechar(t);
    }
  });
  testWidgets('logout limpa rascunho em memória', (t) async {
    final runtime = await abrir(t, perfil: 'GERENTE');
    runtime.rascunhos['venda'] = {'valor': '120,00'};
    await runtime.sessao.sair();
    await t.pumpAndSettle();
    expect(runtime.rascunhos, isEmpty);
    await fechar(t);
  });
  testWidgets('CPF do servidor não é descartado pelo filtro da tela', (
    t,
  ) async {
    await abrir(t, perfil: 'GERENTE', path: '/clientes');
    await t.enterText(find.byType(TextField).first, '52998224725');
    await t.pump(const Duration(milliseconds: 350));
    await t.pumpAndSettle();
    expect(find.text('Cliente A'), findsOneWidget);
    expect(find.text('Nenhum cliente encontrado'), findsNothing);
    await fechar(t);
  });
}
