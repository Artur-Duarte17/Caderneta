import 'package:flutter/material.dart';
import '../../core/app_runtime.dart';
import '../../core/format.dart';
import '../../core/comprovante.dart';

import '../../core/models.dart';
import '../../core/paged_controller.dart';
import '../../core/pagina.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/paginacao.dart';

enum MinhaSecao { resumo, compras, dividas, pagamentos }

class MinhaCadernetaPage extends StatelessWidget {
  const MinhaCadernetaPage({super.key, required this.secao});
  final MinhaSecao secao;
  @override
  Widget build(BuildContext context) => switch (secao) {
    MinhaSecao.resumo => const _Resumo(),
    MinhaSecao.compras => _MinhaLista<Venda>(
      titulo: 'Minhas compras',
      load: (r, p, s) => r.minha.compras(p, s),
      builder: (context, lista) => AppTable(
        colunas: const ['Compra', 'Data', 'Valor', 'Itens'],
        linhas: [
          for (final v in lista)
            [
              Text('#${v.id}'),
              Text(dataHora(v.dataHora)),
              Text(moeda(v.valorTotal)),
              TextButton(
                onPressed: () => showAppDialog(
                  context,
                  titulo: 'Compra #${v.id}',
                  builder: (_, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Total da compra: ${moeda(v.valorTotal)}'),
                      Text(
                        'Soma dos itens: ${moeda(v.itens.fold<double>(0, (s, i) => s + i.subtotal))}',
                      ),
                      Text(
                        'Valor não detalhado: ${moeda(v.valorTotal - v.itens.fold<double>(0, (s, i) => s + i.subtotal))}',
                      ),
                      if (v.itens.isEmpty) const Text('Itens não informados.'),
                      for (final i in v.itens)
                        ListTile(
                          title: Text(i.descricao),
                          subtitle: Text(
                            '${i.quantidade} × ${moeda(i.precoUnitario)}',
                          ),
                          trailing: Text(moeda(i.subtotal)),
                        ),
                      TextButton.icon(
                        onPressed: () =>
                            abrirComprovante('/me/vendas/${v.id}/comprovante'),
                        icon: const Icon(Icons.print),
                        label: const Text('Comprovante da compra'),
                      ),
                    ],
                  ),
                ),
                child: const Text('Detalhes'),
              ),
            ],
        ],
      ),
    ),
    MinhaSecao.dividas => _MinhaLista<Divida>(
      titulo: 'Minhas dívidas e vencimentos',
      load: (r, p, s) => r.minha.dividas(p, s),
      builder: (context, lista) => AppTable(
        colunas: const [
          'Dívida',
          'Vencimento',
          'Original',
          'Pendente',
          'Status',
          'Atraso',
          'Pagamentos',
        ],
        linhas: [
          for (final d in lista)
            [
              Text('#${d.id}'),
              Text(data(d.dataVencimento)),
              Text(moeda(d.valorOriginal)),
              Text(moeda(d.valorPendente)),
              StatusBadge(d.status),
              Text('${d.diasAtraso.clamp(0, 99999)} dias'),
              TextButton(
                onPressed: () => showAppDialog(
                  context,
                  titulo: 'Pagamentos da dívida #${d.id}',
                  builder: (_, _) => d.pagamentos.isEmpty
                      ? const Text('Nenhum pagamento registrado.')
                      : Column(
                          children: [
                            for (final p in d.pagamentos)
                              ListTile(
                                title: Text(moeda(p.valorPago)),
                                subtitle: Text(
                                  '${data(p.dataPagamento)} · ${p.metodo?.label ?? '—'}',
                                ),
                              ),
                          ],
                        ),
                ),
                child: const Text('Ver'),
              ),
            ],
        ],
      ),
    ),
    MinhaSecao.pagamentos => _MinhaLista<Pagamento>(
      titulo: 'Meus pagamentos',
      load: (r, p, s) => r.minha.pagamentos(p, s),
      builder: (_, lista) => AppTable(
        colunas: const ['Data', 'Valor', 'Método', 'Comprovante'],
        linhas: [
          for (final p in lista)
            [
              Text(data(p.dataPagamento)),
              Text(moeda(p.valorPago)),
              Text(p.metodo?.label ?? '—'),
              if (p.id != null && p.dividaId != null)
                IconButton(
                  tooltip: 'Comprovante do pagamento',
                  onPressed: () => abrirComprovante(
                    '/me/dividas/${p.dividaId}/pagamentos/${p.id}/comprovante',
                  ),
                  icon: const Icon(Icons.print),
                )
              else
                const Text('—'),
            ],
        ],
      ),
    ),
  };
}

class _MinhaLista<T> extends StatefulWidget {
  const _MinhaLista({
    required this.titulo,
    required this.load,
    required this.builder,
  });
  final String titulo;
  final Future<Pagina<T>> Function(AppRuntime, int, int) load;
  final Widget Function(BuildContext, List<T>) builder;
  @override
  State<_MinhaLista<T>> createState() => _MinhaListaState<T>();
}

class _MinhaListaState<T> extends State<_MinhaLista<T>> {
  PagedController<T>? _c;
  late AppRuntime _runtime;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c != null) return;
    _runtime = AppScope.of(context);
    _c = PagedController((p, s, _) => widget.load(_runtime, p, s))..atualizar();
    _runtime.historico.revisao.addListener(_atualizar);
  }

  void _atualizar() => _c?.atualizar();
  @override
  void dispose() {
    _runtime.historico.revisao.removeListener(_atualizar);
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PageHeader(titulo: widget.titulo),
      PaginatedSection<T>(
        controller: _c!,
        builder: (lista) => widget.builder(context, lista),
      ),
    ],
  );
}

class _Resumo extends StatelessWidget {
  const _Resumo();
  @override
  Widget build(BuildContext context) {
    final runtime = AppScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          titulo: 'Minha caderneta',
          subtitulo: 'Olá, ${runtime.sessao.usuario!.nome}',
        ),
        const ResumoOperacional(pessoal: true),
        const SizedBox(height: Gap.lg),
        SectionCard(
          titulo: 'Últimos eventos',
          child: AsyncView<Pagina<EventoHistorico>>(
            load: () => runtime.historicoRepo.listar(pessoal: true, size: 5),
            builder: (context, eventos, _) => eventos.content.isEmpty
                ? const Text('Nenhum evento registrado.')
                : Column(
                    children: [
                      for (final e in eventos.content)
                        ListTile(
                          leading: Icon(e.tipo?.icon ?? Icons.history),
                          title: Text(e.mensagem),
                          subtitle: Text(dataHora(e.dataEnvio)),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
