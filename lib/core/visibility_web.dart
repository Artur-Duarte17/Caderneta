import 'dart:js_interop';
import 'package:web/web.dart' as web;

bool abaVisivel() => web.document.visibilityState == 'visible';
void Function() observarVisibilidade(void Function() callback) {
  final listener = ((web.Event event) {
    callback();
  }).toJS;
  web.document.addEventListener('visibilitychange', listener);
  return () => web.document.removeEventListener('visibilitychange', listener);
}
