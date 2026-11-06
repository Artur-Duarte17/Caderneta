import 'package:flutter/foundation.dart';
import 'api_error.dart';
import 'auth_repository.dart';
import 'models.dart';

enum EstadoSessao { verificando, autenticado, naoAutenticado }

class SessaoController extends ChangeNotifier {
  SessaoController(this.auth);
  final AuthRepository auth;
  EstadoSessao estado = EstadoSessao.verificando;
  Usuario? usuario;
  int epoca = 0;
  String? aviso;
  bool ocupado = false;
  bool _disposed = false;
  bool get autenticado => estado == EstadoSessao.autenticado;

  void _notificar() {
    if (!_disposed) notifyListeners();
  }

  Future<void> restaurar() async {
    if (ocupado) return;
    ocupado = true;
    final inicio = epoca;
    estado = EstadoSessao.verificando;
    aviso = null;
    _notificar();
    try {
      await auth.renovarCsrf();
      final user = await auth.me();
      if (inicio != epoca || _disposed) return;
      usuario = user;
      estado = EstadoSessao.autenticado;
    } catch (e) {
      if (inicio != epoca || _disposed) return;
      usuario = null;
      estado = EstadoSessao.naoAutenticado;
      if (e is! ApiException || e.status != 401) aviso = '$e';
    } finally {
      ocupado = false;
      _notificar();
    }
  }

  Future<void> entrar(String login, String senha) async {
    if (ocupado) return;
    ocupado = true;
    final inicio = epoca;
    aviso = null;
    try {
      final user = await auth.login(login.trim(), senha);
      await auth.renovarCsrf();
      if (inicio != epoca || _disposed) throw const RespostaDescartada();
      epoca++;
      usuario = user;
      estado = EstadoSessao.autenticado;
    } finally {
      ocupado = false;
      _notificar();
    }
  }

  void expirar() {
    if (!autenticado) return;
    epoca++;
    usuario = null;
    estado = EstadoSessao.naoAutenticado;
    aviso = 'Sua sessão expirou. Entre novamente.';
    _notificar();
  }

  Future<void> sair() async {
    if (ocupado) return;
    ocupado = true;
    epoca++;
    usuario = null;
    estado = EstadoSessao.naoAutenticado;
    aviso = null;
    _notificar();
    try {
      await auth.logout();
    } catch (e) {
      if (e is! ApiException || e.status != 401) {
        aviso =
            'Você saiu neste dispositivo, mas não foi possível confirmar o encerramento no servidor.';
      }
    }
    try {
      await auth.renovarCsrf();
    } catch (_) {
      /* O aviso de logout tem prioridade. */
    }
    ocupado = false;
    _notificar();
  }

  @override
  void dispose() {
    _disposed = true;
    epoca++;
    super.dispose();
  }
}
