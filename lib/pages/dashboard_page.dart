import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../core/app_runtime.dart';
import '../core/permissoes.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context) {
    final funcionario =
        AppScope.of(context).sessao.usuario?.perfil == Perfil.funcionario;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          titulo: 'Visão Geral',
          subtitulo: funcionario
              ? 'Suas vendas e cobrança compartilhada'
              : 'Vendas e carteira de cobrança',
        ),
        const ResumoOperacional(),
        const SizedBox(height: Gap.lg),
        SectionCard(
          titulo: funcionario ? 'Minhas vendas recentes' : 'Vendas recentes',
          acao: TextButton(
            onPressed: () => context.go('/vendas'),
            child: const Text('Ver todas'),
          ),
          child: AsyncView<Snapshot>(
            load: () => Snapshot.load(),
            builder: (context, s, _) => s.vendas.isEmpty
                ? const Text('Nenhuma venda registrada.')
                : Column(
                    children: [
                      for (final v in s.vendas.take(5))
                        ListTile(
                          title: Text(
                            'Venda #${v.id} · ${s.nomeCliente(v.clienteId)}',
                          ),
                          subtitle: Text(dataHora(v.dataHora)),
                          trailing: Text(moeda(v.valorTotal)),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
