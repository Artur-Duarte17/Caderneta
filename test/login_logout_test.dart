import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caderneta/core/session.dart';
import 'package:caderneta/pages/login_page.dart';
import 'session_polling_test.dart' show AuthStub;

class LogoutPendente extends AuthStub {
  final fim = Completer<void>();
  @override
  Future<void> logout() => fim.future;
}

void main() {
  testWidgets('login volta a aceitar envio quando logout termina', (
    tester,
  ) async {
    final auth = LogoutPendente();
    final sessao = SessaoController(auth);
    await sessao.entrar('a', 'senha');
    final saida = sessao.sair();
    await tester.pumpWidget(MaterialApp(home: LoginPage(sessao: sessao)));
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    auth.fim.complete();
    await saida;
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox());
    sessao.dispose();
  });
}
