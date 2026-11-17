import '../widgets/apresentacao_status.dart';
import 'forms/pagamentos_form.dart';
import 'package:flutter/material.dart';

import '../core/snapshot.dart';
import '../core/app_runtime.dart';
import '../core/comprovante.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../core/periodos.dart';

class PagamentosPage extends StatefulWidget {
  const PagamentosPage({super.key});
  @override
  State<PagamentosPage> createState() => _PagamentosPageState();
}

class _PagamentosPageState extends State<PagamentosPage> {
  String _busca = '';
  int _page = 0;
  Status? _status;
  int _periodo = 0;

  @override
  Widget build(BuildContext context) => AsyncView<Snapshot>(
    cache: 'pagamentos',
    queryKey: (_page, _busca, _status, _periodo),
    mensagem: 'Carregando dívidas e pagamentos',
    mensagemAtualizando: 'Buscando dívidas',
    load: () => AppScope.of(context).operacoes.carregar(
      recurso: 'dividas',
      page: _page,
      q: _busca,
      status: _status?.backend,
      periodo: _periodo,
    ),
    builder: (context, s, _) {
      final termo = _busca.toLowerCase();
      final lista =
          s.dividas.where((d) {
              if (termo.isNotEmpty &&
                  !s.nomeCliente(d.clienteId).toLowerCase().contains(termo)) {
                return false;
              }
              if (_status != null && d.status != _status) return false;
              return dentroDoPeriodo(d.dataEmissao, _periodo);
            }).toList()
            // Em aberto primeiro, ordenadas pelo vencimento mais próximo.
            ..sort((a, b) {
              if (a.status.emAberto != b.status.emAberto) {
                return a.status.emAberto ? -1 : 1;
              }
              return (a.dataVencimento ?? DateTime(9999)).compareTo(
                b.dataVencimento ?? DateTime(9999),
              );
            });

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader(
            titulo: 'Pagamentos',
            subtitulo: 'Acompanhe dívidas e registre pagamentos recebidos',
          ),
          const ResumoOperacional(vendas: false),
          const SizedBox(height: Gap.lg),
          Wrap(
            spacing: Gap.md,
            runSpacing: Gap.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterField(
                width: 300,
                child: SearchField(
                  hint: 'Buscar cliente',
                  onChanged: (v) => setState(() {
                    _busca = v;
                    _page = 0;
                  }),
                ),
              ),
              FilterField(
                child: Dropdown<Status?>(
                  label: 'Status',
                  value: _status,
                  itens: {
                    null: 'Todos',
                    for (final st in Status.values) st: st.label,
                  },
                  onChanged: (v) => setState(() {
                    _status = v;
                    _page = 0;
                  }),
                ),
              ),
              FilterField(
                child: Dropdown<int>(
                  label: 'Emissão',
                  value: _periodo,
                  itens: periodos,
                  onChanged: (v) => setState(() {
                    _periodo = v;
                    _page = 0;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          OperacaoPaginador(
            page: _page,
            total: s.total,
            last: s.last,
            onPage: (p) => setState(() => _page = p),
          ),
          if (lista.isEmpty)
            const EmptyState(
              icon: Icons.inbox_outlined,
              titulo: 'Nenhuma dívida encontrada',
            )
          else
            ResponsiveGrid(
              minWidth: 320,
              children: [
                for (final d in lista)
                  _DividaCard(
                    divida: d,
                    cliente: s.nomeCliente(d.clienteId),
                    onPagar: d.clienteAtivo
                        ? () => _pagar(context, s, d)
                        : null,
                  ),
              ],
            ),
        ],
      );
    },
  );

  Future<void> _pagar(BuildContext context, Snapshot s, Divida d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) =>
          PagamentoForm(divida: d, cliente: s.nomeCliente(d.clienteId)),
    );
    if (ok == true && context.mounted) {
      AppScope.read(context).historico.dadosAlterados();
    }
  }
}

class _DividaCard extends StatelessWidget {
  const _DividaCard({
    required this.divida,
    required this.cliente,
    required this.onPagar,
  });
  final Divida divida;
  final String cliente;
  final VoidCallback? onPagar;

  Widget _valor(
    BuildContext context,
    String label,
    String valor, {
    Color? cor,
  }) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(
          valor,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: cor ?? AppColors.text,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final d = divida;
    final vencida = d.status == Status.vencida;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.ml),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.vendaId == null
                            ? 'Dívida #${d.id}'
                            : 'Venda #${d.vendaId}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        cliente,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                StatusBadge(d.status),
              ],
            ),
            const SizedBox(height: Gap.md),
            Container(
              padding: const EdgeInsets.all(Gap.ms),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _valor(context, 'Valor original', moeda(d.valorOriginal)),
                      _valor(
                        context,
                        'Valor pendente',
                        moeda(d.valorPendente),
                        cor: d.valorPendente > 0
                            ? AppColors.danger
                            : AppColors.success,
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.sm),
                  Row(
                    children: [
                      _valor(context, 'Emissão', data(d.dataEmissao)),
                      _valor(
                        context,
                        'Vencimento',
                        data(d.dataVencimento),
                        cor: vencida ? AppColors.danger : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (AppScope.of(context).sessao.usuario?.perfil == Perfil.gerente &&
                d.status.emAberto)
              TextButton.icon(
                icon: const Icon(Icons.event),
                label: const Text('Renegociar vencimento'),
                onPressed: !d.clienteAtivo
                    ? null
                    : () async {
                        final escolhido = await showDatePicker(
                          context: context,
                          initialDate: d.dataVencimento ?? DateTime.now(),
                          firstDate: d.dataEmissao ?? DateTime(2000),
                          lastDate: DateTime.now().add(
                            const Duration(days: 3650),
                          ),
                        );
                        if (escolhido == null || !context.mounted) return;
                        try {
                          await executarComCarregamento(
                            context,
                            'Atualizando vencimento',
                            () => AppScope.read(
                              context,
                            ).dividas.renegociar(d.id, escolhido),
                          );
                          if (context.mounted) {
                            AppScope.read(context).historico.dadosAlterados();
                          }
                          if (context.mounted) {
                            toast(context, 'Vencimento atualizado');
                          }
                        } catch (e) {
                          if (context.mounted) toast(context, '$e', erro: true);
                        }
                      },
              ),
            if (d.pagamentos.isNotEmpty) ...[
              const SizedBox(height: Gap.md),
              Text(
                'Pagamentos realizados',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: Gap.xs),
              for (final p in d.pagamentos)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Gap.xs),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 16,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: Gap.xs),
                      Text(
                        moeda(p.valorPago),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      if (p.id != null)
                        IconButton(
                          tooltip: 'Comprovante do pagamento',
                          onPressed: () => abrirComprovante(
                            '/dividas/${d.id}/pagamentos/${p.id}/comprovante',
                          ),
                          icon: const Icon(Icons.print, size: 18),
                        ),
                      Flexible(
                        child: Text(
                          '${data(p.dataPagamento)} · ${p.metodo?.label ?? '—'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: Gap.md),
            const Spacer(),
            if (d.status.emAberto)
              FilledButton.icon(
                onPressed: onPagar,
                icon: const Icon(Icons.payments_outlined, size: 18),
                label: const Text('Registrar pagamento'),
              )
            else
              OutlinedButton.icon(
                onPressed: null,
                icon: Icon(d.status.icon, size: 18),
                label: Text(
                  d.status == Status.pago
                      ? 'Dívida quitada'
                      : 'Dívida cancelada',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
