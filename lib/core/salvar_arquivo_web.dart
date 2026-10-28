import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Retorna `true` quando o arquivo foi entregue ao usuário.
Future<bool> salvarArquivo(String nome, Uint8List bytes, String mime) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  web.HTMLAnchorElement()
    ..href = url
    ..download = nome
    ..click();
  web.URL.revokeObjectURL(url);
  return true;
}
