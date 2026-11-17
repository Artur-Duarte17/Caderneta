import '../core/periodos.dart';
import 'forms/vendas_form.dart';
import 'package:flutter/material.dart';

import '../core/snapshot.dart';
import '../core/comprovante.dart';
import '../core/app_runtime.dart';
import '../core/permissoes.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class VendasPage extends StatefulWidget {
  const VendasPage({super.key});
  @override
  State<VendasPage> createState() => _VendasPageState();
}

class _VendasPageState extends State<VendasPage> {
  String _busca = '';
  int _page = 0;
  Status? _status;
  int _periodo = 0;

  @override
  Widget build(BuildContext context) => AsyncView<Snapshot>(
    cache: 'vendas',
    queryKey: (_page, _busca, _status, _periodo),
    mensagem: 'Carregando vendas',
    mensagemAtualizando: 'Buscando vendas',
    load: () => AppScope.of(context).operacoes.carregar(
      recurso: 'vendas',
      page: _page,
      q: _busca,
      status: _status?.backend,
      periodo: _periodo,
    ),
    builder: (context, s, _) {
      final termo = _busca.toLowerCase();
      final lista =
          s.vendas.where((v) {
            if (termo.isNotEmpty &&
                !s.nomeCliente(v.clienteId).toLowerCase().contains(termo) &&
                !'${v.id}'.contains(termo)) {
              return false;
            }
            if (_status != null && s.statusVenda(v) != _status) return false;
            return dentroDoPeriodo(v.dataHora, _periodo);
          }).toList()..sort(
            (a, b) => (b.dataHora ?? DateTime(0)).compareTo(
              a.dataHora ?? DateTime(0),
            ),
          );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            titulo: 'Vendas a prazo',
            subtitulo: '${s.total} venda(s) · Página ${_page + 1}',
            acoes: [
              FilledButton.icon(
                onPressed: () => _form(context, s, null),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nova venda'),
              ),
            ],
          ),
          Wrap(
            spacing: Gap.md,
            runSpacing: Gap.md,
            children: [
              FilterField(
                width: 300,
                child: SearchField(
                  hint: 'Buscar por cliente ou nº da venda',
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
                  label: 'Período',
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
              icon: Icons.receipt_long,
              titulo: 'Nenhuma venda encontrada',
              mensagem: 'Ajuste os filtros ou registre uma nova venda.',
            )
          else
            ResponsiveGrid(
              minWidth: 300,
              children: [
                for (final v in lista)
                  _VendaCard(
                    venda: v,
                    cliente: s.nomeCliente(v.clienteId),
                    status: s.statusVenda(v),
                    onDetalhes: () => _detalhes(context, s, v),
                    onEditar:
                        v.clienteAtivo &&
                            pode(
                              AppScope.of(context).sessao.usuario?.perfil,
                              Acao.editarVenda,
                            )
                        ? () => _form(context, s, v)
                        : null,
                  ),
              ],
            ),
        ],
      );
    },
  );

  void _detalhes(BuildContext context, Snapshot s, Venda v) {
    final d = s.divida(v.dividaId);
    showAppDialog(
      context,
      titulo: 'Venda #${v.id}',
      width: 640,
      builder: (ctx, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.nomeCliente(v.clienteId),
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ),
                StatusBadge(s.statusVenda(v)),
              ],
            ),
            const SizedBox(height: Gap.sm),
            InfoRow('Data da venda', dataHora(v.dataHora)),
            InfoRow('Valor total', moeda(v.valorTotal)),
            if (v.funcionarioNome != null)
              InfoRow('Vendedor', v.funcionarioNome!),
            if (!v.clienteAtivo)
              const Text('Cliente desativado — somente consulta'),
            Wrap(
              spacing: Gap.md,
              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      abrirComprovante('/vendas/${v.id}/comprovante'),
                  icon: const Icon(Icons.print),
                  label: const Text('Comprovante'),
                ),
                if (AppScope.of(context).sessao.usuario?.perfil ==
                        Perfil.gerente &&
                    !v.temPagamentos &&
                    v.clienteAtivo)
                  TextButton(
                    onPressed: () async {
                      final confirmar = await showDialog<bool>(
                        context: ctx,
                        builder: (c) => AlertDialog(
                          title: const Text('Excluir venda?'),
                          content: const Text(
                            'A venda e sua dívida sem pagamentos serão excluídas. A auditoria será preservada.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Excluir'),
                            ),
                          ],
                        ),
                      );
                      if (confirmar == true && ctx.mounted) {
                        try {
                          await executarComCarregamento(
                            ctx,
                            'Excluindo venda',
                            () => AppScope.read(
                              context,
                            ).vendas.excluirVenda(v.id),
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            AppScope.read(context).historico.dadosAlterados();
                          }
                        } catch (e) {
                          if (ctx.mounted) toast(ctx, '$e', erro: true);
                        }
                      }
                    },
                    child: const Text('Excluir venda'),
                  ),
              ],
            ),
            InfoRow(
              'Soma dos itens',
              moeda(v.itens.fold<double>(0, (t, i) => t + i.subtotal)),
            ),
            InfoRow(
              'Valor não detalhado',
              moeda(
                v.valorTotal -
                    v.itens.fold<double>(0, (t, i) => t + i.subtotal),
              ),
            ),
            if (d != null) ...[
              InfoRow(
                'Vencimento',
                data(d.dataVencimento),
                destaque: d.status == Status.vencida ? AppColors.danger : null,
              ),
              InfoRow(
                'Valor pendente',
                moeda(d.valorPendente),
                destaque: d.valorPendente > 0
                    ? AppColors.danger
                    : AppColors.success,
              ),
            ],
            const SizedBox(height: Gap.md),
            const FormSection('Itens'),
            if (v.itens.isEmpty)
              Text(
                'Nenhum item registrado',
                style: Theme.of(ctx).textTheme.bodySmall,
              )
            else
              AppTable(
                colunas: const ['Produto', 'Qtd', 'Unitário', 'Subtotal'],
                numericas: const {1, 2, 3},
                linhas: [
                  for (final i in v.itens)
                    [
                      Text(i.descricao),
                      Text('${i.quantidade}'),
                      Text(moeda(i.precoUnitario)),
                      Text(
                        moeda(i.subtotal),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                ],
              ),
          ],
        );
      },
    );
  }

  Future<void> _form(BuildContext context, Snapshot s, Venda? v) async {
    final api = AppScope.read(context).clientes;
    final clientes = (await api.clientes()).where((c) => c.ativo).toList();
    if (v != null && !clientes.any((c) => c.id == v.clienteId)) {
      clientes.add(await api.cliente(v.clienteId));
    }
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => v == null
          ? NovaVendaForm(clientes: clientes)
          : EditarVendaForm(venda: v, clientes: clientes),
    );
    if (ok == true && context.mounted) {
      AppScope.read(context).historico.dadosAlterados();
    }
  }
}

class _VendaCard extends StatelessWidget {
  const _VendaCard({
    required this.venda,
    required this.cliente,
    required this.status,
    required this.onDetalhes,
    required this.onEditar,
  });
  final Venda venda;
  final String cliente;
  final Status? status;
  final VoidCallback onDetalhes;
  final VoidCallback? onEditar;

  @override
  Widget build(BuildContext context) => Card(
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
                      'Venda #${venda.id}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      data(venda.dataNegocio ?? venda.dataHora),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusBadge(status),
            ],
          ),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              const Icon(
                Icons.person_outline,
                size: 18,
                color: AppColors.muted,
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  cliente,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.xs),
          Text(
            moeda(venda.valorTotal),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          if (venda.funcionarioNome != null)
            Text(
              'Vendedor: ${venda.funcionarioNome}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: Gap.md),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDetalhes,
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Detalhes'),
                ),
              ),
              if (onEditar != null) const SizedBox(width: Gap.sm),
              if (onEditar != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEditar,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Editar'),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
