import 'package:flutter/material.dart';
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
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  for (final width in [360.0, 390.0, 768.0, 1024.0, 1280.0]) {
    testWidgets('login com Roboto em ${width.toInt()} px', (tester) async {
      await abrir(tester, path: '/login', width: width);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/login-${width.toInt()}.png'),
      );
      await fechar(tester);
    }, tags: ['golden']);
  }
}
