/// Public settings. Safe to ship in the app: the publishable key only allows
/// what the database rules allow, and the push key is public by design.
abstract final class Config {
  static const supabaseUrl = 'https://vntfodgrexvrivtmvumx.supabase.co';
  static const supabaseKey = 'sb_publishable_c4221s2kdY3nzDyVpEk02w_6Mnzumj3';

  /// Web push public key; its private half is the VAPID_PRIVATE_KEY secret
  /// of the send-reminders function.
  static const vapidPublicKey =
      'BBZr9u7egIvh1QIOAGF6OzYqep2HMQwGCZfg_ULvUrecFt1MXRzBqfDx5W3s9HWKguAKQeivdy8oKmoNsGIg8D0';

  /// Photo proof bucket.
  static const photoBucket = 'proof';

  /// Days of history loaded at sign-in; older days load when opened.
  static const historyDays = 30;
}
