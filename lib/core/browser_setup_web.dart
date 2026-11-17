import 'package:flutter_web_plugins/url_strategy.dart';

// Preserva o fragmento do link de confirmação sem enviar o token no caminho HTTP.
void prepararNavegador() =>
    setUrlStrategy(PathUrlStrategy(BrowserPlatformLocation(), true));
