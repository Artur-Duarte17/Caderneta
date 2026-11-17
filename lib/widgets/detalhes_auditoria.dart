import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/auditoria_repository.dart';
import 'common.dart';

/// Apresentação legível do contrato de auditoria; mantém JSON só como opção técnica.
class DetalhesAuditoria extends StatelessWidget {
  const DetalhesAuditoria(this.evento, {super.key});
  final Map<String, dynamic> evento;
  @override
  Widget build(BuildContext context) {
    final seguro = semSegredos(evento);
    dynamic alteracoes = seguro['alteracoes'];
    if (alteracoes is String) {
      try {
        alteracoes = jsonDecode(alteracoes);
      } catch (_) {
        /* Evento antigo continua consultável. */
      }
    }
    if (alteracoes is Map) {
      alteracoes = semSegredos(alteracoes);
      seguro['alteracoes'] = alteracoes;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoRow('Autor', '${seguro['atorLogin'] ?? 'Sistema'}'),
        InfoRow('Perfil', '${seguro['perfil'] ?? 'Sistema'}'),
        InfoRow('Ação', '${seguro['acao'] ?? '—'}'),
        InfoRow(
          'Recurso',
          '${seguro['recursoTipo'] ?? '—'} #${seguro['recursoId'] ?? '—'}',
        ),
        InfoRow('Resultado', '${seguro['resultado'] ?? '—'}'),
        if (alteracoes is Map && alteracoes.isNotEmpty)
          for (final campo in alteracoes.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${campo.key}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (campo.value is Map) ...[
                    InfoRow(
                      'Antes',
                      '${campo.value['antes'] ?? 'Não informado'}',
                    ),
                    InfoRow(
                      'Depois',
                      '${campo.value['depois'] ?? 'Não informado'}',
                    ),
                  ] else
                    SelectableText('${campo.value}'),
                ],
              ),
            )
        else
          const Text('Sem alterações de campos registradas.'),
        ExpansionTile(
          title: const Text('Dados técnicos'),
          children: [
            SelectableText(const JsonEncoder.withIndent('  ').convert(seguro)),
          ],
        ),
      ],
    );
  }
}
