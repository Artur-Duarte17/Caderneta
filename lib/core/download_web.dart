import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

void baixarCsv(String csv, String nome) {
  final bytes = Uint8List.fromList(utf8.encode(csv));
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  web.HTMLAnchorElement()
    ..href = url
    ..download = nome
    ..click();
  web.URL.revokeObjectURL(url);
}
