import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// A phone's push address, saved in push_subscriptions.
typedef PushAddress = ({String endpoint, String p256dh, String auth});

bool get _supported =>
    web.window.navigator.has('serviceWorker') && web.window.has('PushManager') && web.window.has('Notification');

/// 'default', 'granted', 'denied' or 'unsupported'.
String pushPermission() {
  if (!_supported) return needsHomeScreen() ? 'default' : 'unsupported';
  try {
    return web.Notification.permission;
  } catch (_) {
    return 'unsupported';
  }
}

bool get _isIos {
  final ua = web.window.navigator.userAgent;
  return ua.contains('iPhone') || ua.contains('iPad');
}

bool get _standalone =>
    web.window.matchMedia('(display-mode: standalone)').matches ||
    (web.window.navigator.getProperty<JSBoolean?>('standalone'.toJS)?.toDart ?? false);

/// An iPhone where the app is open in Safari, not from the Home Screen:
/// iOS only allows push for apps added to the Home Screen.
bool needsHomeScreen() => _isIos && !_standalone;

Uint8List _decodeKey(String key) => base64Url.decode(key.padRight((key.length + 3) ~/ 4 * 4, '='));

String _encode(JSArrayBuffer? buffer) =>
    buffer == null ? '' : base64Url.encode(buffer.toDart.asUint8List()).replaceAll('=', '');

Future<web.ServiceWorkerRegistration> _register() async {
  final workers = web.window.navigator.serviceWorker;
  await workers.register('reminders_sw.js'.toJS).toDart;
  return workers.ready.toDart;
}

PushAddress _address(web.PushSubscription s) =>
    (endpoint: s.endpoint, p256dh: _encode(s.getKey('p256dh')), auth: _encode(s.getKey('auth')));

/// Asks for permission and returns this phone's push address.
Future<PushAddress?> subscribePush(String vapidPublicKey) async {
  if (!_supported) return null;
  final result = await web.Notification.requestPermission().toDart;
  if (result.toDart != 'granted') return null;
  final reg = await _register();
  final existing = await reg.pushManager.getSubscription().toDart;
  final sub =
      existing ??
      await reg.pushManager
          .subscribe(
            web.PushSubscriptionOptionsInit(
              userVisibleOnly: true,
              applicationServerKey: _decodeKey(vapidPublicKey).toJS,
            ),
          )
          .toDart;
  return _address(sub);
}

/// This phone's push address if it already allowed reminders.
Future<PushAddress?> currentPush(String vapidPublicKey) async {
  if (pushPermission() != 'granted') return null;
  try {
    return await subscribePush(vapidPublicKey);
  } catch (_) {
    return null;
  }
}
