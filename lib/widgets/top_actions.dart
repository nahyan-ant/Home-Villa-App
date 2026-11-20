import 'package:flutter/material.dart';

import '../app_state.dart';
import '../hindi.dart';
import '../screens/emergency.dart';
import '../theme.dart';

/// Emergency, then Sign out: on every signed-in screen.
List<Widget> topActions(BuildContext context) {
  final state = AppScope.of(context);
  return [
    IconButton(
      icon: const Icon(Icons.emergency_outlined, color: Palette.alert),
      tooltip: tr1('Emergency'),
      onPressed: () =>
          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const EmergencyScreen())),
    ),
    TextButton(onPressed: () => _signOut(context, state), child: Text(Lang.on ? 'साइन आउट' : 'Sign out')),
    const SizedBox(width: 4),
  ];
}

Future<void> _signOut(BuildContext context, AppState state) async {
  final waiting = state.waitingToSend;
  if (waiting > 0) {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr1('Not sent yet')),
        content: Text(
          '$waiting ${waiting == 1 ? 'change is' : 'changes are'} still on this phone. '
          'Signing out now loses ${waiting == 1 ? 'it' : 'them'}. Wait for the internet first.'
          '${Lang.on ? '\n\n$waiting बदलाव अभी इस फ़ोन में हैं। अभी साइन आउट करने पर ये खो जाएँगे। पहले इंटरनेट का इंतज़ार करें।' : ''}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(tr1('Stay'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Palette.alert, minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(tr1('Sign out anyway')),
          ),
        ],
      ),
    );
    if (sure != true) return;
  }
  await state.signOut();
}
