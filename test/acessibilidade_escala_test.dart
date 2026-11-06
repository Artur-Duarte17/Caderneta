import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app_test.dart' show abrir, fechar;

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    final fonts = FontLoader('Roboto');
    for (final nome in ['Regular', 'Medium', 'Bold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Roboto-$nome.ttf'));
    }
    await fonts.load();
  });
  testWidgets('telas com texto a 200% nas cinco larguras e navegação por Tab', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final width in [360.0, 390.0, 768.0, 1024.0, 1280.0]) {
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
        '/minha/historico',
      ]) {
        final perfil = path.startsWith('/minha')
            ? 'CLIENTE'
            : path == '/login' || path == '/ativar'
            ? null
            : 'GERENTE';
        await abrir(tester, perfil: perfil, path: path, width: width);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: '$path em $width px, texto 200%',
        );
        await fechar(tester);
      }
    }
  });
}
