import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/app_runtime.dart';
import '../core/auditoria_repository.dart';
import '../core/dates.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/paged_controller.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/paginacao.dart';

class AuditoriaPage extends StatefulWidget {
  const AuditoriaPage({super.key});
  @override
  State<AuditoriaPage> createState() => _AuditoriaPageState();
}

class _AuditoriaPageState extends State<AuditoriaPage> {
  PagedController<AuditoriaEvento>? _c;
  final _acao = TextEditingController(), _recurso = TextEditingController();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _c ??= PagedController(AppScope.of(context).auditoria.listar)..atualizar();
  }

  void _filtrar() {
    final f = Map.of(_c!.filtros)
      ..remove('acao')
      ..remove('recursoTipo');
    if (_acao.text.trim().isNotEmpty) f['acao'] = _acao.text.trim();
    if (_recurso.text.trim().isNotEmpty) {
      f['recursoTipo'] = _recurso.text.trim();
    }
    _c!.filtrar(f);
  }

  @override
  void dispose() {
    _c?.dispose();
    _acao.dispose();
    _recurso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _c!,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(
          titulo: 'Auditoria',
          subtitulo: 'Ações administrativas e alterações de recursos',
        ),
        Wrap(
          spacing: Gap.md,
          runSpacing: Gap.md,
          children: [
            FilterField(
              child: TextField(
                controller: _acao,
                decoration: const InputDecoration(labelText: 'Ação'),
                onSubmitted: (_) => _filtrar(),
              ),
            ),
            FilterField(
              child: TextField(
                controller: _recurso,
                decoration: const InputDecoration(labelText: 'Tipo de recurso'),
                onSubmitted: (_) => _filtrar(),
              ),
            ),
            PeriodoFiltro(
              filtros: _c!.filtros,
              onChanged: (range) {
                final f = Map.of(_c!.filtros)
                  ..remove('inicio')
                  ..remove('fim');
                if (range != null) {
                  f.addAll(limitesPeriodo(range.start, range.end));
                }
                _c!.filtrar(f);
              },
            ),
            OutlinedButton(
              onPressed: _filtrar,
              child: const Text('Aplicar filtros'),
            ),
            TextButton(
              onPressed: () {
                _acao.clear();
                _recurso.clear();
                _c!.filtrar({});
              },
              child: const Text('Limpar filtros'),
            ),
          ],
        ),
        const SizedBox(height: Gap.md),
        PaginatedSection<AuditoriaEvento>(
          controller: _c!,
          builder: (lista) => AppTable(
            colunas: const [
              'Instante',
              'Ator',
              'Perfil',
              'Ação',
              'Recurso',
              'Resultado',
              'Detalhes',
            ],
            linhas: [
              for (final e in lista)
                [
                  Text(dataHora(parseData(e.json['ocorridoEm']))),
                  Text(e.ator),
                  Text(e.perfil),
                  Text(e.texto('acao')),
                  Text(e.recurso),
                  Text(e.texto('resultado')),
                  TextButton(
                    onPressed: () => showAppDialog(
                      context,
                      titulo: 'Detalhes da auditoria',
                      builder: (_, _) => SelectableText(
                        const JsonEncoder.withIndent(
                          '  ',
                        ).convert(semSegredos(e.json)),
                      ),
                    ),
                    child: const Text('Ver'),
                  ),
                ],
            ],
          ),
        ),
      ],
    ),
  );
}
