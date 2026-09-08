import 'dart:js_interop';

@JS('btwInstall.status')
external JSString _statusJs();
@JS('btwInstall.install')
external JSPromise<JSBoolean> _installJs();
@JS('btwInstall.dismiss')
external void _dismissJs();

class AppInstallService {
  static Future<String> status() async => _statusJs().toDart;
  static Future<bool> install() async => (await _installJs().toDart).toDart;
  static void dismiss() => _dismissJs();
}
