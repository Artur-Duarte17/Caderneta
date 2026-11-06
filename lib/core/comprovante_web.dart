import 'package:web/web.dart' as web;
import 'http_gateway.dart';

void abrirComprovante(String caminho) {
  web.window.open(apiUri(apiBaseUrl, caminho).toString(), '_blank', 'noopener');
}
