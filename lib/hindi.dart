import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'theme.dart';

/// English + Hindi. Each phone chooses for itself (the हिन्दी button on a
/// maid's screen); when on, Hindi shows next to the English.
class Lang {
  static bool on = false;
  static Box<bool>? _box;

  /// Call after Hive is set up.
  static Future<void> load() async {
    _box = await Hive.openBox<bool>('prefs');
    on = _box!.get('hindi') ?? false;
  }

  static void set(bool value) {
    on = value;
    _box?.put('hindi', value);
  }
}

/// The Hindi for [en], or null when Hindi is off or not known.
String? hindiOf(String en) => Lang.on ? _hi[en.trim()] : null;

/// [en] with its Hindi on the next line.
String tr(String en) {
  final hi = hindiOf(en);
  return hi == null ? en : '$en\n$hi';
}

/// [en] with its Hindi on the same line, for buttons and tabs.
String tr1(String en) {
  final hi = hindiOf(en);
  return hi == null ? en : '$en · $hi';
}

/// A sentence with numbers or names in it, written in both languages.
String bi(String en, String hi) => Lang.on ? '$en\n$hi' : en;

/// Same, on one line.
String bi1(String en, String hi) => Lang.on ? '$en · $hi' : en;

/// The Hindi under a task's English title or details; nothing when off.
class HindiLine extends StatelessWidget {
  const HindiLine(this.en, {super.key, this.size = 14, this.color = Palette.muted});

  final String en;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final hi = hindiOf(en);
    if (hi == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(hi, style: TextStyle(color: color, fontSize: size, height: 1.4)),
    );
  }
}

const _hi = <String, String>{
  // ---------------------------------------------------------- tasks
  'Wake-up punch-in': 'सुबह की हाज़िरी',
  'Take a photo when you start your day.': 'दिन शुरू करते समय एक फ़ोटो लें।',
  'Arrive and prepare breakfast': 'पहुँचें और नाश्ता बनाएँ',
  'Reach Villa 15 by 7:00 AM sharp': 'सुबह ठीक 7:00 बजे तक विला 15 पहुँचें',
  'Breakfast service': 'नाश्ता परोसना',
  'Serve Mama and Papa; morning medicines with breakfast':
      'मामा और पापा को नाश्ता परोसें; नाश्ते के साथ सुबह की दवाइयाँ',
  'Kitchen clean-up': 'रसोई की सफ़ाई',
  'Wash breakfast dishes, wipe counters and stove': 'नाश्ते के बर्तन धोएँ, काउंटर और चूल्हा पोंछें',
  'Fridge and kitchen cupboard arrangement': 'फ्रिज और रसोई की अलमारी जमाना',
  'Check expiry dates, arrange items, update the inventory / shopping list':
      'एक्सपायरी तारीख़ देखें, सामान जमाएँ, सामान / ख़रीदारी की सूची अपडेट करें',
  'Lunch cooking': 'दोपहर का खाना बनाना',
  '2 hours of cooking': '2 घंटे खाना बनाना',
  "While Mama is out at physiotherapy, also batch-prep staff food and dinner ingredients, and have a drink and light snack ready for Mama's return at 12:00":
      'जब मामा फ़िज़ियोथेरेपी के लिए बाहर हों, तब स्टाफ़ का खाना और रात के खाने की सामग्री भी तैयार करें, '
      'और 12:00 बजे मामा के लौटने पर कुछ पीने को और हल्का नाश्ता तैयार रखें',
  'Clean-up and table setting': 'सफ़ाई और मेज़ लगाना',
  'Wash cooking dishes, set the table': 'खाना बनाने के बर्तन धोएँ, मेज़ लगाएँ',
  'Lunch': 'दोपहर का खाना',
  'Serve lunch at 1:00 PM; afternoon medicines; clear and wash dishes':
      'दोपहर 1:00 बजे खाना परोसें; दोपहर की दवाइयाँ; मेज़ साफ़ करें और बर्तन धोएँ',
  'Break': 'आराम',
  '2 hours': '2 घंटे',
  '1 hour': '1 घंटा',
  '30 minutes': '30 मिनट',
  'Evening tea and kitchen upkeep': 'शाम की चाय और रसोई की देखभाल',
  'Prepare evening tea / snacks for Mama and Papa; deep-clean kitchen surfaces and stove; finalise list of items to buy':
      'मामा और पापा के लिए शाम की चाय / नाश्ता बनाएँ; रसोई की सतहें और चूल्हा अच्छी तरह साफ़ करें; '
      'ख़रीदने वाले सामान की सूची पक्की करें',
  'Dinner preparation': 'रात का खाना बनाना',
  'Dinner and closing': 'रात का खाना और रसोई बंद करना',
  'Serve dinner at 8:00 PM; evening medicines; wash all dishes and close the kitchen':
      'रात 8:00 बजे खाना परोसें; शाम की दवाइयाँ; सारे बर्तन धोएँ और रसोई बंद करें',
  'Lunch break': 'दोपहर का आराम',
  'Evening break': 'शाम का आराम',
  'Rest break': 'आराम',
  'Dinner break': 'रात के खाने का आराम',
  'Office cleaning': 'ऑफ़िस की सफ़ाई',
  'Vital checks': 'स्वास्थ्य जाँच',

  // ---------------------------------------------------------- labels
  'Morning medicines': 'सुबह की दवाइयाँ',
  'Afternoon medicines': 'दोपहर की दवाइयाँ',
  'Evening medicines': 'शाम की दवाइयाँ',
  'Mama': 'मामा',
  'Papa': 'पापा',
  'Free time': 'खाली समय',
  'Warning': 'चेतावनी',
  'Final warning': 'आख़िरी चेतावनी',
  'Action': 'कार्रवाई',
  'Replacement day off': 'बदले में छुट्टी',
  'Extra pay': 'अतिरिक्त पैसे',

  // ---------------------------------------------------------- screens
  'Today': 'आज',
  'Shopping list': 'ख़रीदारी की सूची',
  'Meal plan': 'खाने का प्लान',
  'No meal plan today': 'आज कोई खाने का प्लान नहीं',
  'Follow the pictures. Take a photo of each dish when it is ready.': 'तस्वीरें देखकर बनाएँ। हर खाना तैयार होने पर उसकी फ़ोटो लें।',
  'Photo when ready': 'तैयार होने पर फ़ोटो',
  'Undo?': 'वापस लें?',
  'This dish will show as not made again.': 'यह खाना फिर से "नहीं बना" दिखेगा।',
  'Sign out': 'साइन आउट',
  'Emergency': 'आपातकाल',
  'NOW': 'अभी',
  'MISSED': 'छूट गया',
  'Saved on this phone, not sent yet': 'इस फ़ोन में सेव है, अभी भेजा नहीं गया',
  'Open shopping list': 'ख़रीदारी की सूची खोलें',
  'Photo needed as proof': 'सबूत के लिए फ़ोटो ज़रूरी है',
  'Photo of common areas only': 'सिर्फ़ खुली जगहों की फ़ोटो',
  'Enter BP, blood sugar and oxygen': 'BP, शुगर और ऑक्सीजन लिखें',
  'Medicine time': 'दवाई का समय',
  'In 10 minutes': '10 मिनट में',
  'Open': 'खोलें',
  'Later': 'बाद में',
  'Not now': 'अभी नहीं',
  'Turn on': 'चालू करें',
  'OK': 'ठीक है',
  'Add this app to your Home Screen': 'यह ऐप होम स्क्रीन पर जोड़ें',
  'iPhone only sends reminders to apps on the Home Screen. In Safari tap the Share button, then "Add to Home Screen". Open the app from there and turn on reminders.':
      'iPhone सिर्फ़ होम स्क्रीन वाले ऐप को याद दिलाता है। Safari में Share बटन दबाएँ, फिर "Add to Home Screen"। '
      'वहाँ से ऐप खोलें और रिमाइंडर चालू करें।',
  'Turn on reminders': 'रिमाइंडर चालू करें',
  'Your phone tells you when a task or a medicine is due, and when one is not done yet.':
      'काम या दवाई का समय होने पर, और काम बाक़ी रहने पर फ़ोन आपको बताएगा।',
  'Reminders are blocked': 'रिमाइंडर बंद हैं',
  'Allow notifications for this app in the phone settings to get task reminders.':
      'रिमाइंडर पाने के लिए फ़ोन की सेटिंग में इस ऐप के नोटिफ़िकेशन चालू करें।',
  '12-hour duty with a 2-hour break. Log every break and free time.':
      '12 घंटे की ड्यूटी, 2 घंटे का आराम। हर आराम और खाली समय दर्ज करें।',
  'Start break': 'आराम शुरू',
  'Start free time': 'खाली समय शुरू',
  'No checklist today. If there is an event, you will be told in advance.':
      'आज कोई काम नहीं। कोई कार्यक्रम होगा तो पहले बता दिया जाएगा।',

  // task sheet
  'Undo': 'वापस लें',
  'This was already sent. Undo it when the internet is back.': 'यह भेजा जा चुका है। इंटरनेट आने पर वापस लें।',
  "I couldn't do this task": 'मैं यह काम नहीं कर पाई',
  'Record each dose with a photo first.': 'पहले हर दवाई फ़ोटो के साथ दर्ज करें।',
  'Enter the readings and add a photo.': 'रीडिंग लिखें और फ़ोटो लगाएँ।',
  'Add a photo as proof first.': 'पहले सबूत के लिए फ़ोटो लगाएँ।',
  'Save readings': 'रीडिंग सेव करें',
  'Mark done': 'पूरा हुआ',
  'You are responsible for this dose.': 'यह दवाई देना आपकी ज़िम्मेदारी है।',
  'Take a photo of the medicine for each dose. Everyone sees who gave it, so it is never given twice.':
      'हर दवाई की फ़ोटो लें। सबको दिखता है कि किसने दी, ताकि दवाई दो बार न दी जाए।',
  'No internet: you cannot see if someone else already gave this dose. Ask the others before giving it.':
      'इंटरनेट नहीं है: पता नहीं चलेगा कि किसी और ने दवाई दे दी है या नहीं। देने से पहले दूसरों से पूछें।',
  'Not given yet': 'अभी नहीं दी',
  'Already given. Do not give again.': 'दी जा चुकी है। दोबारा न दें।',
  'Given': 'दे दी',
  'Only you and admin can see these readings.': 'ये रीडिंग सिर्फ़ आप और एडमिन देख सकते हैं।',
  'BP top': 'BP ऊपर',
  'BP bottom': 'BP नीचे',
  'Blood sugar': 'शुगर',
  'Oxygen': 'ऑक्सीजन',
  'MORE PHOTOS (OPTIONAL)': 'और फ़ोटो (ज़रूरी नहीं)',
  'PHOTO PROOF': 'फ़ोटो सबूत',
  'Never take photos in bedrooms or bathrooms, and never of Mama or Papa. For care tasks, photo the tray, meal, clothes or medicine instead.':
      'बेडरूम या बाथरूम में और मामा-पापा की फ़ोटो कभी न लें। देखभाल के काम में ट्रे, खाना, कपड़े या दवाई की फ़ोटो लें।',
  'Take photo': 'फ़ोटो लें',
  'Add another photo': 'एक और फ़ोटो',
  'Only you and admin can see these photos.': 'ये फ़ोटो सिर्फ़ आप और एडमिन देख सकते हैं।',
  'Remove note': 'नोट हटाएँ',
  'Save note': 'नोट सेव करें',
  'Note (optional)': 'नोट (ज़रूरी नहीं)',
  "Couldn't do it": 'नहीं कर पाई',
  'It still counts as missed. Say why, so admin knows.': 'यह फिर भी छूटा हुआ गिना जाएगा। कारण लिखें ताकि एडमिन को पता चले।',
  'Why?': 'क्यों?',
  'Cancel': 'रद्द करें',
  'Save': 'सेव करें',

  // shopping
  'What does the house need?': 'घर में क्या चाहिए?',
  'Add groceries, cleaning materials or anything else needed. Admin sees it at once.':
      'राशन, सफ़ाई का सामान या जो भी चाहिए, जोड़ें। एडमिन को तुरंत दिखेगा।',
  'No internet: changes are saved on this phone and sent when the internet is back.':
      'इंटरनेट नहीं है: बदलाव इस फ़ोन में सेव हैं और इंटरनेट आने पर भेजे जाएँगे।',
  'Item': 'सामान',
  'Quantity': 'मात्रा',
  'No items yet.': 'अभी कोई सामान नहीं।',
  'You asked': 'आपने माँगा',
  'Bought': 'ख़रीद लिया',

  // sign out
  'Not sent yet': 'अभी भेजा नहीं गया',
  'Stay': 'रुकें',
  'Sign out anyway': 'फिर भी साइन आउट',

  // emergency
  'CALL': 'फ़ोन करें',
  'WHAT TO DO': 'क्या करें',
  'If the app is not working, post the photos in the family WhatsApp group with the time and task.':
      'अगर ऐप नहीं चल रहा, तो फ़ोटो समय और काम के साथ परिवार के WhatsApp ग्रुप में भेजें।',
  'NIGHT EMERGENCY': 'रात की आपात स्थिति',
  'If someone was up at night with an emergency, the other maid covers her morning tasks so she can rest.':
      'अगर कोई रात में आपात स्थिति के कारण जागी, तो दूसरी मेड उसके सुबह के काम करेगी ताकि वह आराम कर सके।',
  'Log a night emergency': 'रात की आपात स्थिति दर्ज करें',
  'Night emergency': 'रात की आपात स्थिति',
  'Who was up and rests': 'कौन जागी और आराम करेगी',
  'Who covers the morning': 'सुबह के काम कौन करेगी',
  'What happened': 'क्या हुआ',
};
