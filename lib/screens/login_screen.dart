import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Sign in, or create an account that waits for an admin to approve it.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _creating = false;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final state = AppScope.of(context);
    String? problem;
    if (!_email.text.contains('@')) problem = 'Enter your email.';
    if (_password.text.length < (_creating ? 8 : 1)) {
      problem = _creating ? 'The password needs at least 8 characters.' : 'Enter your password.';
    }
    if (_creating && (_name.text.trim().isEmpty || _phone.text.trim().isEmpty)) {
      problem = 'Enter your name and mobile number.';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final error = _creating
        ? await state.signUp(name: _name.text, email: _email.text, phone: _phone.text, password: _password.text)
        : await state.signIn(_email.text, _password.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
      if (error == null && _creating && state.needsEmailCheck) {
        _info = 'Account made. Open the email we sent you and tap the link, then sign in here.';
        _creating = false;
      }
    });
  }

  Future<void> _forgot() async {
    final state = AppScope.of(context);
    final email = await showDialog<String>(
      context: context,
      builder: (_) => _EmailDialog(initial: _email.text.trim()),
    );
    if (email == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final error = await state.sendPasswordReset(email);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
      if (error == null) {
        _info = 'If $email has an account, an email is on its way. Open the link on this phone to set a new password.';
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: AutofillGroup(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
          children: [
            const Stagger(
              index: 0,
              child: Row(
                children: [
                  Logo(),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Home Checklist',
                          style: TextStyle(fontFamily: 'DMSerifDisplay', fontSize: 34, height: 1.05),
                        ),
                        SizedBox(height: 4),
                        Text('Daily tasks for the household team', style: TextStyle(color: Palette.muted, fontSize: 15)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              _creating ? 'Create your account' : 'Sign in',
              style: const TextStyle(fontFamily: 'DMSerifDisplay', fontSize: 24),
            ),
            const SizedBox(height: 14),
            if (_creating) ...[
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(labelText: 'Your name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: const InputDecoration(labelText: 'Mobile number', hintText: 'For example: +971 50 123 4567'),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              autofillHints: [_creating ? AutofillHints.newPassword : AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Password',
                helperText: _creating ? 'At least 8 characters. Remember it.' : null,
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Palette.alert, fontSize: 14)),
            ],
            if (_info != null) ...[
              const SizedBox(height: 12),
              InfoBanner(icon: Icons.mark_email_read_outlined, text: _info!),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Please wait…' : (_creating ? 'Create account' : 'Sign in')),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _creating = !_creating;
                      _error = null;
                      _info = null;
                    }),
              child: Text(_creating ? 'I already have an account' : 'New here? Create an account'),
            ),
            if (!_creating)
              TextButton(
                onPressed: _busy ? null : _forgot,
                child: const Text('Forgot password?'),
              ),
            if (_creating) ...[
              const SizedBox(height: 8),
              const Text(
                'An admin approves new accounts before you can see your tasks.',
                style: TextStyle(color: Palette.muted, fontSize: 13, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}


class _EmailDialog extends StatefulWidget {
  const _EmailDialog({required this.initial});

  final String initial;

  @override
  State<_EmailDialog> createState() => _EmailDialogState();
}

class _EmailDialogState extends State<_EmailDialog> {
  late final _email = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Reset password'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('We email you a link to set a new password.', style: bodyMutedTall),
        const SizedBox(height: 12),
        TextField(
          controller: _email,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
          onChanged: (_) => setState(() {}),
        ),
      ],
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
        onPressed: _email.text.contains('@') ? () => Navigator.of(context).pop(_email.text.trim()) : null,
        child: const Text('Send link'),
      ),
    ],
  );
}

/// Opened from the reset email: choose a new password.
class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _password = TextEditingController();
  final _again = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_password.text.length < 8) {
      setState(() => _error = 'The password needs at least 8 characters.');
      return;
    }
    if (_password.text != _again.text) {
      setState(() => _error = 'The two passwords are not the same.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await AppScope.of(context).setNewPassword(_password.text);
    if (mounted) {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: AutofillGroup(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
          children: [
            const Logo(),
            const SizedBox(height: 24),
            const Text('Set a new password', style: TextStyle(fontFamily: 'DMSerifDisplay', fontSize: 26)),
            const SizedBox(height: 14),
            TextField(
              controller: _password,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: const InputDecoration(labelText: 'New password', helperText: 'At least 8 characters.'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _again,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password again'),
              onSubmitted: (_) => _save(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Palette.alert, fontSize: 14)),
            ],
            const SizedBox(height: 20),
            FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Please wait…' : 'Save password')),
          ],
        ),
      ),
    ),
  );
}
