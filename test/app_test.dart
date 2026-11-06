import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:caderneta/core/app_runtime.dart';
import 'package:caderneta/main.dart';
import 'package:caderneta/dev/fakes.dart';
import 'package:caderneta/widgets/app_shell.dart';
import 'package:caderneta/widgets/convite_dialog.dart';
import 'package:caderneta/core/models.dart' show Cliente;

Map<String, dynamic> user(String perfil, {bool b = false}) => {
  'id': perfil == 'GERENTE'
      ? 1
      : perfil == 'FUNCIONARIO'
      ? 2
      : b
      ? 4
      : 3,
  'pessoaId': perfil == 'CLIENTE' ? (b ? 21 : 20) : 10,
  'nome': perfil == 'CLIENTE'
      ? (b ? 'Cliente B' : 'Cliente A')
      : 'Usuário de teste',
  'login': 'teste',
  'perfil': perfil,
};
Future<AppRuntime> abrir(
  WidgetTester tester, {
  String? perfil,
  String path = '/',
  ServidorSimulado? servidor,
  double width = 1280,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  final fake = servidor ?? ServidorSimulado(latencia: Duration.zero);
  if (perfil != null) fake.usuario = user(perfil);
  final runtime = AppRuntime(client: fake.client, simulado: true);
  await tester.pumpWidget(
    CadernetaApp(runtime: runtime, initialLocation: path),
  );
  await tester.pumpAndSettle();
  return runtime;
}

Future<void> fechar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  testWidgets('conteúdo protegido não é construído enquanto verifica sessão', (
    tester,
  ) async {
    final me = Completer<http.Response>();
    final r = AppRuntime(
      client: MockClient(
        (req) async => req.url.path.endsWith('/csrf')
            ? http.Response(
                jsonEncode({'token': 'x', 'headerName': 'X-CSRF-TOKEN'}),
                200,
              )
            : me.future,
      ),
    );
    await tester.pumpWidget(CadernetaApp(runtime: r));
    await tester.pump();
    expect(find.byType(AppShell), findsNothing);
    expect(find.text('Visão Geral'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    me.complete(http.Response('{}', 401));
    await tester.pumpAndSettle();
    expect(find.text('Entre na Caderneta'), findsOneWidget);
    await fechar(tester);
  });
  testWidgets(
    'login inválido é genérico, limpa senha e bloqueia envio duplicado',
    (tester) async {
      final fake = ServidorSimulado(latencia: Duration.zero);
      await abrir(tester, servidor: fake);
      await tester.enterText(find.byType(TextFormField).at(0), 'inexistente');
      await tester.enterText(find.byType(TextFormField).at(1), 'senha');
      await tester.tap(find.text('Entrar'));
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
      expect(fake.caminhos.where((p) => p == '/api/auth/login').length, 1);
      expect(find.text('Login ou senha inválidos.'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(0))
            .controller!
            .text,
        'inexistente',
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(1))
            .controller!
            .text,
        '',
      );
      await fechar(tester);
    },
  );
  for (final perfil in ['GERENTE', 'FUNCIONARIO', 'CLIENTE']) {
    testWidgets('menu e rota proibida para $perfil', (tester) async {
      await abrir(tester, perfil: perfil);
      final context = tester.element(find.byType(AppShell));
      final router = GoRouter.of(context);
      expect(
        find.text('Auditoria'),
        perfil == 'GERENTE' ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Relatórios'),
        perfil == 'GERENTE' ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Acessos'),
        perfil == 'GERENTE' ? findsOneWidget : findsNothing,
      );
      if (perfil == 'CLIENTE') {
        expect(find.text('Minha caderneta'), findsOneWidget);
        router.go('/clientes');
      } else if (perfil == 'FUNCIONARIO') {
        expect(find.text('Vendas no mês'), findsNothing);
        router.go('/vendas');
        await tester.pumpAndSettle();
        expect(find.text('Editar'), findsNothing);
        router.go('/auditoria');
      } else {
        router.go('/minha');
      }
      await tester.pumpAndSettle();
      expect(find.text('Acesso negado'), findsOneWidget);
      await fechar(tester);
    });
  }
  testWidgets('expiração durante uso remove dados e mostra aviso no login', (
    tester,
  ) async {
    final fake = ServidorSimulado(latencia: Duration.zero);
    final r = await abrir(tester, perfil: 'CLIENTE', servidor: fake);
    fake.expirar();
    await r.historico.consultar();
    await tester.pumpAndSettle();
    expect(find.text('Entre na Caderneta'), findsOneWidget);
    expect(find.text('Sua sessão expirou. Entre novamente.'), findsOneWidget);
    expect(find.text('Minha caderneta'), findsNothing);
    await fechar(tester);
  });
  testWidgets('logout e login de B desmontam dados e filtros de A', (
    tester,
  ) async {
    final fake = ServidorSimulado(latencia: Duration.zero);
    final r = await abrir(
      tester,
      perfil: 'CLIENTE',
      servidor: fake,
      path: '/minha/compras',
    );
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('#2'), findsNothing);
    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();
    expect(find.text('#1'), findsNothing);
    await tester.enterText(find.byType(TextFormField).at(0), 'cliente.b');
    await tester.enterText(find.byType(TextFormField).at(1), 'qualquer');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(r.sessao.usuario!.nome, 'Cliente B');
    GoRouter.of(tester.element(find.byType(AppShell))).go('/minha/compras');
    await tester.pumpAndSettle();
    expect(find.text('#2'), findsOneWidget);
    expect(find.text('#1'), findsNothing);
    await fechar(tester);
  });
  testWidgets(
    'rota antiga redireciona e histórico preserva página ao chegar evento',
    (tester) async {
      final fake = ServidorSimulado(latencia: Duration.zero);
      final r = await abrir(
        tester,
        perfil: 'GERENTE',
        servidor: fake,
        path: '/notificacoes',
      );
      final router = GoRouter.of(tester.element(find.byType(AppShell)));
      expect(router.state.uri.path, '/historico');
      await tester.ensureVisible(find.byTooltip('Próxima página'));
      await tester.tap(find.byTooltip('Próxima página'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Página 2 de'), findsOneWidget);
      r.historico.novosEventos = 2;
      r.historico.revisao.value++;
      await tester.pumpAndSettle();
      expect(find.text('2 novos eventos · Atualizar'), findsOneWidget);
      expect(find.textContaining('Página 2 de'), findsOneWidget);
      await fechar(tester);
    },
  );
  testWidgets('primeira página do histórico atualiza mantendo filtro ativo', (
    tester,
  ) async {
    final fake = ServidorSimulado(latencia: Duration.zero);
    final r = await abrir(
      tester,
      perfil: 'GERENTE',
      servidor: fake,
      path: '/historico',
    );
    await tester.tap(find.text('Todos os tipos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compra realizada').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Página 1 de 1 · 12 eventos'), findsOneWidget);

    await r.gateway.send(
      'POST',
      '/vendas',
      body: {
        'clienteId': 20,
        'itens': [
          {
            'descricaoProduto': 'Pedido novo de teste',
            'quantidade': 1,
            'precoUnitario': 10,
          },
        ],
      },
    );
    r.historico.novosEventos = 1;
    r.historico.revisao.value++;
    await tester.pumpAndSettle();

    expect(find.text('Compra registrada'), findsOneWidget);
    expect(find.textContaining('Página 1 de 1 · 13 eventos'), findsOneWidget);
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .initialValue,
      'COMPRA_REALIZADA',
    );
    expect(find.text('1 novos eventos · Atualizar'), findsNothing);
    await fechar(tester);
  });
  testWidgets('convite exige geração explícita e código desaparece ao fechar', (
    tester,
  ) async {
    final fake = ServidorSimulado(latencia: Duration.zero);
    final r = await abrir(tester, perfil: 'GERENTE', servidor: fake);
    final novo = await r.gateway.send(
      'POST',
      '/clientes',
      body: {'nome': 'Convidado', 'cpf': '52998224725'},
    );
    final context = tester.element(find.byType(AppShell));
    final dialog = showDialog<void>(
      context: context,
      builder: (_) => ConviteDialog(cliente: Cliente.fromJson(novo)),
    );
    await tester.pumpAndSettle();
    expect(fake.caminhos.where((p) => p.endsWith('/convite')), isEmpty);
    await tester.tap(find.text('Gerar código'));
    await tester.pumpAndSettle();
    expect(fake.caminhos.where((p) => p.endsWith('/convite')).length, 1);
    expect(
      find.text('Este código só é exibido agora. Compartilhe com o cliente.'),
      findsOneWidget,
    );
    expect(find.text('Copiar'), findsOneWidget);
    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();
    await dialog;
    expect(find.text('Copiar'), findsNothing);
    await fechar(tester);
  });
  testWidgets(
    'gestão de acessos pede confirmação e preserva situação se cancelar',
    (tester) async {
      final fake = ServidorSimulado(latencia: Duration.zero);
      await abrir(tester, perfil: 'GERENTE', path: '/acessos', servidor: fake);
      await tester.tap(find.text('Desativar').first);
      await tester.pumpAndSettle();
      expect(find.text('Desativar acesso?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(fake.caminhos.where((p) => p.endsWith('/ativo')), isEmpty);
      await tester.tap(find.text('Desativar').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(fake.caminhos.where((p) => p.endsWith('/ativo')).length, 1);
      expect(find.text('Inativo'), findsOneWidget);
      await fechar(tester);
    },
  );
  testWidgets('ativação válida retorna ao login sem autenticar', (
    tester,
  ) async {
    final fake = ServidorSimulado(latencia: Duration.zero);
    final r = await abrir(tester, perfil: 'GERENTE', servidor: fake);
    final novo = await r.gateway.send(
      'POST',
      '/clientes',
      body: {'nome': 'Novo acesso', 'cpf': '52998224725'},
    );
    final convite = await r.acessos.convite(novo['id']);
    await r.sessao.sair();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Primeiro acesso'));
    await tester.pumpAndSettle();
    final values = [
      '52998224725',
      convite.codigo,
      'novo.acesso',
      'senha-teste',
      'senha-teste',
    ];
    for (var i = 0; i < values.length; i++) {
      await tester.enterText(find.byType(TextFormField).at(i), values[i]);
    }
    await tester.tap(find.widgetWithText(FilledButton, 'Ativar acesso'));
    await tester.pumpAndSettle();
    expect(r.sessao.autenticado, false);
    expect(find.text('Entre na Caderneta'), findsOneWidget);
    expect(
      find.text('Acesso criado. Entre com seu login e senha.'),
      findsOneWidget,
    );
    await fechar(tester);
  });
  testWidgets(
    'diálogos de operação cabem no celular e conflito mantém edição',
    (tester) async {
      for (final entry in [
        ('/clientes', 'Novo cliente'),
        ('/vendas', 'Nova venda'),
        ('/vendas', 'Editar'),
        ('/pagamentos', 'Registrar pagamento'),
        ('/acessos', 'Criar funcionário'),
      ]) {
        final fake = ServidorSimulado(latencia: Duration.zero);
        await abrir(
          tester,
          perfil: 'GERENTE',
          path: entry.$1,
          servidor: fake,
          width: 360,
        );
        final button = find.text(entry.$2).first;
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: entry.toString());
        if (entry.$2 == 'Registrar pagamento') {
          await tester.enterText(find.byType(TextFormField).first, '1');
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'aviso de pagamento parcial',
          );
        }
        if (entry.$2 == 'Editar') {
          final title = tester
              .widget<Text>(find.textContaining('Editar venda #'))
              .data!;
          final id = RegExp(r'#(\d+)').firstMatch(title)!.group(1);
          fake.falhas['/vendas/$id'] = 409;
          await tester.ensureVisible(find.text('Salvar alterações'));
          await tester.tap(find.text('Salvar alterações'));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(fake.caminhos.where((p) => p == '/api/vendas/$id').length, 1);
          expect(find.text('Operação não permitida.'), findsOneWidget);
        }
        await fechar(tester);
      }
    },
  );
  for (final width in [360.0, 390.0, 768.0, 1024.0, 1280.0]) {
    testWidgets('layout sem overflow em ${width.toInt()} px', (tester) async {
      for (final path in [
        '/login',
        '/ativar',
        '/',
        '/clientes',
        '/vendas',
        '/pagamentos',
        '/relatorios',
        '/historico',
        '/auditoria',
        '/acessos',
        '/minha',
        '/minha/compras',
        '/minha/dividas',
        '/minha/pagamentos',
      ]) {
        final perfil = path.startsWith('/minha')
            ? 'CLIENTE'
            : path == '/login' || path == '/ativar'
            ? null
            : 'GERENTE';
        await abrir(tester, perfil: perfil, path: path, width: width);
        expect(tester.takeException(), isNull, reason: '$path em $width px');
        if (path == '/login') {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/login-${width.toInt()}.png'),
          );
        }
        await fechar(tester);
      }
    });
  }
}
