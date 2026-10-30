import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_state.dart';
import 'config.dart';
import 'outbox.dart';
import 'screens/admin_shell.dart';
import 'screens/login_screen.dart';
import 'screens/maid_shell.dart';
import 'theme.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final outbox = await Outbox.open();
  await Supabase.initialize(url: Config.supabaseUrl, publishableKey: Config.supabaseKey);
  runApp(HomeChecklistApp(state: AppState(outbox)));
}

class HomeChecklistApp extends StatefulWidget {
  const HomeChecklistApp({super.key, required this.state});

  final AppState state;

  @override
  State<HomeChecklistApp> createState() => _HomeChecklistAppState();
}

class _HomeChecklistAppState extends State<HomeChecklistApp> {
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  late final StreamSubscription<String> _messages;

  @override
  void initState() {
    super.initState();
    _messages = widget.state.messages.listen(
      (text) => messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(text), duration: const Duration(seconds: 4)),
      ),
    );
  }

  @override
  void dispose() {
    _messages.cancel();
    widget.state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(
    state: widget.state,
    child: MaterialApp(
      scaffoldMessengerKey: messengerKey,
      title: 'Home Checklist',
      theme: buildTheme(),
      debugShowCheckedModeBanner: false,
      home: const _Root(),
      // A phone-width column, centred on wide screens.
      builder: (context, child) => ColoredBox(
        color: Palette.side,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Material(color: Palette.page, child: child),
          ),
        ),
      ),
    ),
  );
}

/// Sign-in screen, or the signed-in person's own screens.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final user = state.user;
    final Widget screen;
    final String key;
    if (state.session == null) {
      screen = const LoginScreen();
      key = 'login';
    } else if (state.recovering) {
      screen = const NewPasswordScreen();
      key = 'recover';
    } else if (user == null) {
      screen = state.loading ? const _Loading() : const _NoAccess(removed: false);
      key = 'wait';
    } else if (user.isPending) {
      screen = const _Waiting();
      key = 'pending';
    } else if (user.removedFrom != null) {
      screen = const _NoAccess(removed: true);
      key = 'removed';
    } else {
      screen = user.isAdmin ? AdminShell(user: user) : MaidShell(user: user);
      key = user.id;
    }
    return Swap(swapKey: key, child: screen);
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _Waiting extends StatelessWidget {
  const _Waiting();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Logo(),
              const SizedBox(height: 20),
              Text(
                'Hi ${state.user!.name}, your account is waiting for approval',
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'DMSerifDisplay', fontSize: 24, height: 1.2),
              ),
              const SizedBox(height: 8),
              const Text(
                'An admin will approve it. Then your tasks show here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Palette.muted, fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: state.reload, child: const Text('Check again')),
              TextButton(onPressed: state.signOut, child: const Text('Sign out')),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoAccess extends StatelessWidget {
  const _NoAccess({required this.removed});

  final bool removed;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              removed
                  ? 'This account is no longer on the team.'
                  : 'Could not load your account. Check the internet and try again.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            if (!removed)
              FilledButton(onPressed: AppScope.of(context).reload, child: const Text('Try again')),
            TextButton(onPressed: AppScope.of(context).signOut, child: const Text('Sign out')),
          ],
        ),
      ),
    ),
  );
}
