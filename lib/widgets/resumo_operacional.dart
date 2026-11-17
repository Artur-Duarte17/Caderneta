import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/app_runtime.dart';

import 'async_view.dart';
import 'layout.dart';

class ResumoOperacional extends StatelessWidget {
  const ResumoOperacional({
    super.key,
    this.pessoal = false,
    this.vendas = true,
  });
  final bool pessoal, vendas;
  @override
  Widget build(BuildContext context) => AsyncView<Map<String, dynamic>>(
    cache: 'resumo',
    queryKey: pessoal,
    mensagem: 'Carregando resumo',
    load: () => AppScope.read(context).operacoes.resumo(pessoal: pessoal),
    builder: (context, r, _) => ResponsiveGrid(
      minWidth: 240,
      children: [
        StatCard(
          label: pessoal ? 'Saldo devedor' : 'Saldo da cobrança compartilhada',
          valor: moeda(r['saldo'] as num?),
          icon: Icons.account_balance_wallet_outlined,
        ),
        if (vendas && !pessoal)
          StatCard(
            label: 'Vendas no mês (seu acesso)',
            valor: moeda(r['vendasMes'] as num?),
            icon: Icons.receipt_long_outlined,
          ),
        StatCard(
          label: 'Recebido no mês',
          valor: moeda(r['recebidoMes'] as num?),
          icon: Icons.payments_outlined,
        ),
        StatCard(
          label: 'Dívidas vencidas',
          valor: '${r['vencidas'] ?? 0}',
          icon: Icons.warning_amber_rounded,
        ),
        if (pessoal)
          StatCard(
            label: 'Próximo vencimento',
            valor: data(DateTime.tryParse('${r['proximoVencimento']}')),
            icon: Icons.event,
          ),
      ],
    ),
  );
}
