/// Salva/compartilha um arquivo gerado pelo app. No navegador baixa o arquivo;
/// no Android abre o menu de compartilhamento (Drive, Arquivos, WhatsApp…).
library;

export 'salvar_arquivo_io.dart' if (dart.library.js_interop) 'salvar_arquivo_web.dart';
