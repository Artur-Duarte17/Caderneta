import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_runtime.dart';
import '../core/permissoes.dart';
import '../widgets/common.dart';

class AcessoNegadoPage extends StatelessWidget {
  const AcessoNegadoPage({super.key});
  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.lock_outline,
    titulo: 'Acesso negado',
    mensagem: AppScope.of(context).sessao.usuario?.perfil == null
        ? 'Seu perfil não foi reconhecido. Entre em contato com o responsável.'
        : 'Seu perfil não tem acesso a esta página.',
    acao: TextButton(
      onPressed: () =>
          context.go(entrada(AppScope.of(context).sessao.usuario?.perfil)),
      child: const Text('Voltar ao início'),
    ),
  );
}
