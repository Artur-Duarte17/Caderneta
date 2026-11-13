import 'package:flutter/material.dart';

/// Faz o conteúdo surgir suavemente: aparece (fade) subindo alguns pixels.
///
/// Anima só ao entrar na tela; reconstruções seguintes (ex.: atualização em
/// segundo plano) não repetem a animação. Use [ordem] para escalonar itens de
/// uma lista ou grade (cada um começa um pouco depois do anterior).
/// Respeita a preferência de "reduzir movimento" do sistema.
class Surgir extends StatefulWidget {
  const Surgir({
    super.key,
    required this.child,
    this.ordem = 0,
    this.deslocamento = 16,
    this.duracao = const Duration(milliseconds: 380),
    this.intervalo = const Duration(milliseconds: 55),
    this.maxOrdem = 8,
  });

  final Widget child;
  final int ordem;
  final double deslocamento;
  final Duration duracao, intervalo;

  /// A partir desta posição o atraso para de crescer, para listas longas
  /// não demorarem a aparecer.
  final int maxOrdem;

  @override
  State<Surgir> createState() => _SurgirState();
}

class _SurgirState extends State<Surgir> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    final atraso = widget.intervalo * widget.ordem.clamp(0, widget.maxOrdem);
    final total = atraso + widget.duracao;
    _c = AnimationController(vsync: this, duration: total);
    final inicio = total.inMicroseconds == 0
        ? 0.0
        : atraso.inMicroseconds / total.inMicroseconds;
    _t = CurvedAnimation(
      parent: _c,
      curve: Interval(inicio, 1, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isDismissed) {
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        _c.value = 1;
      } else {
        _c.forward();
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _t,
    child: AnimatedBuilder(
      animation: _t,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, (1 - _t.value) * widget.deslocamento),
        child: child,
      ),
      child: widget.child,
    ),
  );
}
