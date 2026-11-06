import 'package:web/web.dart' as web;

String? ler(String key) => web.window.sessionStorage.getItem(key);
void salvar(String key, String value) {
  web.window.sessionStorage.setItem(key, value);
}

void remover(String key) {
  web.window.sessionStorage.removeItem(key);
}
