/// A phone's push address, saved in push_subscriptions.
typedef PushAddress = ({String endpoint, String p256dh, String auth});

/// 'default', 'granted', 'denied' or 'unsupported'.
String pushPermission() => 'unsupported';

/// An iPhone where the app is open in Safari, not from the Home Screen:
/// iOS only allows push for apps added to the Home Screen.
bool needsHomeScreen() => false;

/// Asks for permission and returns this phone's push address.
Future<PushAddress?> subscribePush(String vapidPublicKey) async => null;

/// This phone's push address if it already allowed reminders.
Future<PushAddress?> currentPush(String vapidPublicKey) async => null;
