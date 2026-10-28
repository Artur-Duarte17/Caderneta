import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Retorna `true` quando o usuário escolheu um destino para o arquivo.
Future<bool> salvarArquivo(String nome, Uint8List bytes, String mime) async {
  final r = await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: mime, name: nome)],
      fileNameOverrides: [nome],
      subject: nome,
    ),
  );
  return r.status != ShareResultStatus.dismissed;
}
