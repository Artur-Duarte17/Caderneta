import 'package:flutter/material.dart';
import '../core/app_runtime.dart';
import '../core/catalogo_repository.dart';
import '../core/entrada_numerica.dart';
import '../core/format.dart';
import '../core/pagina.dart';
import '../widgets/common.dart';

class CatalogoPage extends StatefulWidget {
  const CatalogoPage({super.key});
  @override
  State<CatalogoPage> createState() => _CatalogoPageState();
}

class _CatalogoPageState extends State<CatalogoPage> {
  String _q = '';
  int _page = 0, _revisao = 0;
  Future<void> _editar([ItemCatalogo? item]) async {
    final descricao = TextEditingController(text: item?.descricao);
    final preco = TextEditingController(
      text: item?.precoSugerido?.toStringAsFixed(2).replaceAll('.', ',') ?? '',
    );
    final key = GlobalKey<FormState>();
    bool ativo = item?.ativo ?? true, busy = false;
    String? erro;
    final repo = AppScope.of(context).catalogoManutencao;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(
            item == null ? 'Novo item frequente' : 'Editar item frequente',
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Form(
                key: key,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: descricao,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        labelText: 'Descrição *',
                      ),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'Informe a descrição'
                          : null,
                    ),
                    TextFormField(
                      controller: preco,
                      keyboardType: tecladoValor,
                      inputFormatters: somenteValorMonetario(),
                      decoration: const InputDecoration(
                        labelText: 'Preço sugerido (opcional)',
                        prefixText: r'R$ ',
                      ),
                      validator: (v) =>
                          (v ?? '').trim().isNotEmpty &&
                              (parseCentavos(v!) ?? 0) <= 0
                          ? 'Informe um preço positivo'
                          : null,
                    ),
                    SwitchListTile(
                      title: const Text('Ativo nas sugestões'),
                      value: ativo,
                      onChanged: busy ? null : (v) => set(() => ativo = v),
                    ),
                    if (erro != null) Text(erro!),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            BusyButton(
              label: 'Salvar',
              busyLabel: 'Salvando',
              busy: busy,
              onPressed: () async {
                if (busy || !key.currentState!.validate()) return;
                set(() {
                  busy = true;
                  erro = null;
                });
                try {
                  await repo.salvar(
                    id: item?.id,
                    descricao: descricao.text.trim(),
                    precoSugerido: preco.text.trim().isEmpty
                        ? null
                        : parseCentavos(preco.text)! / 100,
                    ativo: ativo,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) setState(() => _revisao++);
                } catch (e) {
                  if (ctx.mounted) {
                    set(() {
                      busy = false;
                      erro = '$e';
                    });
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
    // Aguarda a animação de saída antes de liberar controladores usados pelo diálogo.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    descricao.dispose();
    preco.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PageHeader(
        titulo: 'Itens frequentes',
        subtitulo:
            'Sugestões opcionais para agilizar o detalhamento. Sem controle de estoque.',
        acoes: [
          FilledButton.icon(
            onPressed: () => _editar(),
            icon: const Icon(Icons.add),
            label: const Text('Novo item'),
          ),
        ],
      ),
      SearchField(
        hint: 'Buscar item',
        onChanged: (v) => setState(() {
          _q = v;
          _page = 0;
        }),
      ),
      AsyncView<Pagina<ItemCatalogo>>(
        queryKey: (_q, _page, _revisao),
        load: () => AppScope.of(
          context,
        ).catalogoConsulta.listar(page: _page, q: _q, incluirInativos: true),
        builder: (context, p, _) => Column(
          children: [
            OperacaoPaginador(
              page: _page,
              total: p.totalElements,
              last: p.last,
              onPage: (v) => setState(() => _page = v),
            ),
            for (final item in p.content)
              ListTile(
                title: Text(item.descricao),
                subtitle: Text(
                  '${item.precoSugerido == null ? 'Sem preço sugerido' : moeda(item.precoSugerido)} · ${item.ativo ? 'Ativo' : 'Inativo'}',
                ),
                trailing: IconButton(
                  tooltip: 'Editar item',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _editar(item),
                ),
              ),
            if (p.content.isEmpty) const Text('Nenhum item encontrado'),
          ],
        ),
      ),
    ],
  );
}
