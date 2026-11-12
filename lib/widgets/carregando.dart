import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Indicadores de carregamento usados em todo o sistema.
///
///  * [Carregando]: círculo + "Carregando..." (tela ou bloco ainda sem dados).
///  * [BarraAtualizando]: barra fina + "Atualizando..." (dados já na tela sendo recarregados).
///  * [TextoCarregando]: texto com os 3 pontinhos animados (botões, mensagens).
///  * [executarComCarregamento]: janela de espera para ações rápidas (excluir, renegociar...).

/// Texto com reticências animadas: "Carregando", "Carregando.", "Carregando..", "Carregando...".
/// O espaço dos pontos é reservado para o texto não "pular" a cada quadro.
class TextoCarregando extends StatefulWidget {
  const TextoCarregando(this.texto, {super.key, this.style});
  final String texto;
  final TextStyle? style;

  @override
  State<TextoCarregando> createState() => _TextoCarregandoState();
}

class _TextoCarregandoState extends State<TextoCarregando>
    with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    // Leitores de tela anunciam só o texto, sem repetir a cada ponto.
    label: '${widget.texto}...',
    liveRegion: true,
    child: ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          final pontos = (_anim.value * 4).floor() % 4;
          return Text.rich(
            TextSpan(
              text: widget.texto,
              children: [
                TextSpan(text: '.' * pontos),
                TextSpan(
                  text: '.' * (3 - pontos),
                  style: const TextStyle(color: Colors.transparent),
                ),
              ],
            ),
            style: widget.style,
          );
        },
      ),
    ),
  );
}

/// Círculo + mensagem com reticências. Para telas e blocos que ainda não têm dados.
class Carregando extends StatelessWidget {
  const Carregando({
    super.key,
    this.mensagem = 'Carregando',
    this.compacto = false,
  });
  final String mensagem;
  final bool compacto;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.all(compacto ? Gap.md : Gap.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: compacto ? 28 : 40,
            height: compacto ? 28 : 40,
            child: const CircularProgressIndicator(),
          ),
          const SizedBox(height: Gap.md),
          TextoCarregando(
            mensagem,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}

/// Barra fina + mensagem. Para recarregamentos com os dados antigos ainda visíveis.
class BarraAtualizando extends StatelessWidget {
  const BarraAtualizando({super.key, this.mensagem = 'Atualizando'});
  final String mensagem;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Gap.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LinearProgressIndicator(),
        const SizedBox(height: 4),
        TextoCarregando(
          mensagem,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
        ),
      ],
    ),
  );
}

/// Mostra uma janela de espera (não pode ser fechada) enquanto [acao] executa.
/// Fecha sozinha ao terminar, com sucesso ou erro; o erro é repassado a quem chamou.
Future<T> executarComCarregamento<T>(
  BuildContext context,
  String mensagem,
  Future<T> Function() acao,
) async {
  final navegador = Navigator.of(context, rootNavigator: true);
  var aberta = true;
  showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: Dialog(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.xl,
            vertical: Gap.lg,
          ),
          child: Carregando(mensagem: mensagem, compacto: true),
        ),
      ),
    ),
  ).whenComplete(() => aberta = false);
  try {
    return await acao();
  } finally {
    if (aberta && navegador.mounted) navegador.pop();
  }
}
