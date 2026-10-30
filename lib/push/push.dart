/// Push reminders that arrive even when the app is closed.
///
/// The web build uses the browser's push service; other builds have none yet.
library;

export 'push_stub.dart' if (dart.library.js_interop) 'push_web.dart';
