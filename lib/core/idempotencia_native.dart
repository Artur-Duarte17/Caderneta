final _chaves = <String, String>{};
String? ler(String key) => _chaves[key];
void salvar(String key, String value) {
  _chaves[key] = value;
}

void remover(String key) {
  _chaves.remove(key);
}
