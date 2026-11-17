import 'dart:async';
import 'package:flutter/material.dart';

import '../core/app_runtime.dart';
import '../core/cache_telas.dart';
import '../core/theme.dart';

import 'animacoes.dart';
import 'carregando.dart';

// ===== Carregamento assíncrono padronizado =====

/// Carrega dados, mostra loading/erro de forma uniforme e recarrega sozinho
/// quando outra parte do app altera dados (venda criada, pagamento etc.).
class AsyncView<T> extends StatefulWidget {
  const AsyncView({
    super.key,
    required this.load,
    required this.builder,
    this.queryKey,
    this.mensagem = 'Carregando dados',
    this.mensagemAtualizando = 'Atualizando',
    this.cache,
  });

  final Object? queryKey;

  /// Nome da tela no [CacheTelas]. Quando informado, os últimos dados vistos
  /// (para a mesma [queryKey]) aparecem na hora e são atualizados em segundo
  /// plano.
  final String? cache;

  /// Texto do indicador na primeira carga (sem dados) e nas recargas (dados antigos na tela).
  final String mensagem, mensagemAtualizando;

  final Future<T> Function() load;
  final Widget Function(
    BuildContext context,
    T data,
    Future<void> Function() reload,
  )
  builder;

  @override
  State<AsyncView<T>> createState() => _AsyncViewState<T>();
}

class _AsyncViewState<T> extends State<AsyncView<T>> {
  T? _data;
  Object? _erro;
  bool _carregando = true;
  bool _atualizando = false;
  int _pedido = 0;
  ValueNotifier<int>? _revisao;
  CacheTelas? _cache;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final runtime = context
        .dependOnInheritedWidgetOfExactType<AppScope>()
        ?.runtime;
    final revisao = runtime?.historico.revisao;
    if (!identical(_revisao, revisao) || _pedido == 0) {
      _revisao?.removeListener(_reload);
      _revisao = revisao;
      _cache = runtime?.cache;
      _data = null;
      _revisao?.addListener(_reload);
      _reload();
    }
  }

  @override
  void didUpdateWidget(covariant AsyncView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.queryKey != widget.queryKey) _reload();
  }

  @override
  void dispose() {
    _pedido++;
    _data = null;
    _revisao?.removeListener(_reload);
    super.dispose();
  }

  T? _doCache() => widget.cache == null
      ? null
      : _cache?.ler<T>(widget.cache!, widget.queryKey);

  Future<void> _reload() async {
    final pedido = ++_pedido;
    final guardado = _doCache();
    setState(() {
      if (guardado != null) {
        _data = guardado;
        _erro = null;
      }
      if (_data == null) _carregando = true;
      _atualizando = _data != null;
    });
    try {
      final d = await widget.load();
      if (mounted && pedido == _pedido) {
        if (widget.cache != null) {
          _cache?.gravar(widget.cache!, widget.queryKey, d);
        }
        setState(() {
          _data = d;
          _erro = null;
          _carregando = false;
          _atualizando = false;
        });
      }
    } catch (e) {
      if (mounted && pedido == _pedido) {
        setState(() {
          _erro = e;
          _carregando = false;
          _atualizando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando && _data == null) {
      return LoadingState(mensagem: widget.mensagem);
    }
    if (_erro != null && _data == null) {
      return ErrorState(mensagem: '$_erro', onRetry: _reload);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_atualizando)
          BarraAtualizando(mensagem: widget.mensagemAtualizando),
        if (_erro != null) ErrorState(mensagem: '$_erro', onRetry: _reload),
        KeyedSubtree(
          key: const ValueKey('async-content'),
          // Anima só na primeira exibição: a busca/atualização mantém o
          // estado (campo de busca, foco) e não repete a animação.
          child: Surgir(child: widget.builder(context, _data as T, _reload)),
        ),
      ],
    );
  }
}

class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.mensagem = 'Carregando'});
  final String mensagem;
  @override
  Widget build(BuildContext context) => Carregando(mensagem: mensagem);
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.mensagem, this.onRetry});
  final String mensagem;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.cloud_off,
    titulo: 'Não foi possível carregar os dados',
    mensagem: mensagem,
    acao: onRetry == null
        ? null
        : OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.titulo,
    this.mensagem,
    this.acao,
  });
  final IconData icon;
  final String titulo;
  final String? mensagem;
  final Widget? acao;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(
        vertical: Gap.xxl,
        horizontal: Gap.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.muted.withValues(alpha: .5)),
          const SizedBox(height: Gap.md),
          Text(
            titulo,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (mensagem != null) ...[
            const SizedBox(height: Gap.xs),
            Text(
              mensagem!,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
          if (acao != null) ...[const SizedBox(height: Gap.md), acao!],
        ],
      ),
    ),
  );
}
