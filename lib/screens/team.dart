import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../templates.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Add, change or remove maids and admins.
class TeamScreen extends StatelessWidget {
  const TeamScreen({super.key});

  Future<void> _open(BuildContext context, {required bool isAdmin, Person? person}) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => PersonEditor(person: person, isAdmin: isAdmin)));

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Team')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (state.waitingToJoin.isNotEmpty) ...[
            const Text('WAITING TO JOIN', style: sectionLabel),
            const SizedBox(height: 8),
            for (final p in state.waitingToJoin) _WaitingCard(person: p),
            const SizedBox(height: 16),
          ],
          _PeopleCard(
            label: 'MAIDS',
            people: state.maidsOn(state.today),
            addLabel: 'Add a maid',
            onTap: (p) => _open(context, isAdmin: false, person: p),
            onAdd: () => _open(context, isAdmin: false),
          ),
          const SizedBox(height: 24),
          _PeopleCard(
            label: 'ADMINS',
            people: state.admins,
            addLabel: 'Add an admin',
            onTap: (p) => _open(context, isAdmin: true, person: p),
            onAdd: () => _open(context, isAdmin: true),
          ),
          const SizedBox(height: 16),
          const Text(
            'Each person gets their own sign-in. Removing someone takes them off from today; '
            'their earlier days stay in the history.',
            style: TextStyle(color: Palette.muted, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _PeopleCard extends StatelessWidget {
  const _PeopleCard({
    required this.label,
    required this.people,
    required this.addLabel,
    required this.onTap,
    required this.onAdd,
  });

  final String label;
  final List<Person> people;
  final String addLabel;
  final ValueChanged<Person> onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(child: Text(label, style: sectionLabel)),
          TextButton.icon(icon: const Icon(Icons.add), label: Text(addLabel), onPressed: onAdd),
        ],
      ),
      const SizedBox(height: 4),
      Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (final (i, p) in people.indexed)
              InkWell(
                onTap: () => onTap(p),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: i == people.length - 1
                        ? null
                        : const Border(bottom: BorderSide(color: Palette.line)),
                  ),
                  child: Row(
                    children: [
                      Avatar(
                        id: p.id,
                        name: p.name,
                        size: 40,
                        style: const TextStyle(color: Palette.white, fontFamily: 'DMSerifDisplay', fontSize: 19),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            if (p.phone.isNotEmpty || p.duties.isNotEmpty || p.hours.isNotEmpty)
                              Text(
                                [p.phone, p.duties, p.hours].where((s) => s.isNotEmpty).join(' · '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: bodyMuted,
                              ),
                          ],
                        ),
                      ),
                      const Icon(Icons.edit_outlined, size: 18, color: Palette.muted),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

class PersonEditor extends StatefulWidget {
  const PersonEditor({super.key, this.person, required this.isAdmin});

  /// Null when adding someone.
  final Person? person;
  final bool isAdmin;

  @override
  State<PersonEditor> createState() => _PersonEditorState();
}

class _PersonEditorState extends State<PersonEditor> {
  late final _name = TextEditingController(text: widget.person?.name ?? '');
  late final _email = TextEditingController(text: widget.person?.email ?? '');
  late final _phone = TextEditingController(text: widget.person?.phone ?? '');
  late final _password = TextEditingController();
  late final _duties = TextEditingController(text: widget.person?.duties ?? '');
  late final _hours = TextEditingController(text: widget.person?.hours ?? '');

  /// "template:mary" or "copy:" plus a person id: what a new maid starts with.
  String? _startWith;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password, _duties, _hours]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isNew => widget.person == null;

  bool get _ready =>
      _name.text.trim().isNotEmpty &&
      (!_isNew || (_email.text.contains('@') && _password.text.length >= 8 && _phone.text.trim().isNotEmpty));

  Future<void> _save(AppState state) async {
    final person = widget.person;
    if (person != null) {
      state.updatePerson(
        person,
        name: _name.text.trim(),
        duties: _duties.text.trim(),
        hours: _hours.text.trim(),
        phone: _phone.text.trim(),
      );
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final start = _startWith;
    final error = await state.createPerson(
      name: _name.text.trim(),
      email: _email.text.trim(),
      password: _password.text,
      phone: _phone.text.trim(),
      isAdmin: widget.isAdmin,
      duties: _duties.text.trim(),
      hours: _hours.text.trim(),
      template: start != null && start.startsWith('template:') ? start.substring(9) : null,
      copyFrom: start != null && start.startsWith('copy:') ? start.substring(5) : null,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _resetPassword(AppState state) async {
    final password = await showDialog<String>(context: context, builder: (_) => const _PasswordDialog());
    if (password == null || !mounted) return;
    final error = await state.resetPassword(widget.person!, password);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Password changed. Tell ${widget.person!.name} the new one.')),
    );
  }

  Future<void> _remove(AppState state) async {
    final person = widget.person!;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${person.name}?'),
        content: Text(
          person.isAdmin
              ? '${person.name} will no longer be able to sign in.'
              : '${person.name} comes off the team today, with her tasks, and can no longer sign in. '
                    'Her earlier days stay in the history.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Palette.alert, minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    final error = await state.removePerson(person);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final person = widget.person;
    final kind = widget.isAdmin ? 'admin' : 'maid';
    final blocked = person == null ? null : state.cannotRemove(person);
    void changed(String _) => setState(() {});
    return Scaffold(
      appBar: AppBar(title: Text(person == null ? 'New $kind' : 'Edit ${person.name}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          TextField(
            controller: _name,
            autofocus: person == null,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
            onChanged: changed,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            enabled: _isNew,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email (to sign in)',
              helperText: _isNew ? 'Their own email, or a new one made for them.' : null,
            ),
            onChanged: changed,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Mobile number', hintText: 'For example: +971 50 123 4567'),
            onChanged: changed,
          ),
          if (_isNew) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              decoration: const InputDecoration(
                labelText: 'Password',
                helperText: 'At least 8 characters. Give it to them; they sign in with it.',
              ),
              onChanged: changed,
            ),
          ],
          if (!widget.isAdmin) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _duties,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Duties (short)',
                hintText: "For example: Parents' care, villa inspection",
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _hours,
              decoration: const InputDecoration(labelText: 'Working hours', hintText: 'For example: 7 AM – 9 PM'),
            ),
          ],
          if (person == null && !widget.isAdmin) ...[
            const SizedBox(height: 20),
            const Text('START WITH TASKS FROM', style: sectionLabel),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: _startWith,
              isExpanded: true,
              items: [
                const DropdownMenuItem(value: null, child: Text('No tasks yet: I will add them')),
                for (final e in scheduleTemplates.entries)
                  DropdownMenuItem(value: 'template:${e.key}', child: Text('${e.value} (21 Oct 2026)')),
                for (final m in state.maidsOn(state.today))
                  DropdownMenuItem(value: 'copy:${m.id}', child: Text("A copy of ${m.name}'s current schedule")),
              ],
              onChanged: (v) => setState(() => _startWith = v),
            ),
            const SizedBox(height: 6),
            const Text('You can change the tasks afterwards under Schedules.', style: bodyMutedTall),
          ],
          const SizedBox(height: 28),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(_error!, style: const TextStyle(color: Palette.alert, fontSize: 14)),
            ),
          FilledButton(
            onPressed: !_ready || _busy ? null : () => _save(state),
            child: Text(_busy ? 'Adding…' : (person == null ? 'Add $kind' : 'Save')),
          ),
          if (person != null) ...[
            const SizedBox(height: 10),
            OutlinedButton(onPressed: () => _resetPassword(state), child: const Text('Set a new password')),
            const SizedBox(height: 10),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Palette.alert),
              onPressed: blocked == null ? () => _remove(state) : null,
              child: Text('Remove ${person.name}'),
            ),
            if (blocked != null) Text(blocked, textAlign: TextAlign.center, style: bodyMuted),
          ],
        ],
      ),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New password'),
    content: TextField(
      controller: _password,
      autofocus: true,
      decoration: const InputDecoration(labelText: 'Password', helperText: 'At least 8 characters.'),
      onChanged: (_) => setState(() {}),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
        onPressed: _password.text.length < 8 ? null : () => Navigator.of(context).pop(_password.text),
        child: const Text('Save'),
      ),
    ],
  );
}


/// Someone who created an account and waits for approval.
class _WaitingCard extends StatelessWidget {
  const _WaitingCard({required this.person});

  final Person person;

  Future<void> _reject(BuildContext context, AppState state) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reject ${person.name}?'),
        content: const Text('Their account is deleted. They can sign up again later.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Palette.alert, minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (sure != true || !context.mounted) return;
    final error = await state.reject(person);
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 8),
      decoration: BoxDecoration(
        color: Palette.butter,
        border: Border.all(color: Palette.ink, width: 1.5),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(person.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text([person.email, person.phone].where((s) => s.isNotEmpty).join(' \u00b7 '), style: bodyMuted),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 4,
              children: [
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Palette.alert),
                  onPressed: () => _reject(context, state),
                  child: const Text('Reject'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => _ApproveDialog(state: state, person: person),
                  ),
                  child: const Text('Approve'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApproveDialog extends StatefulWidget {
  const _ApproveDialog({required this.state, required this.person});

  final AppState state;
  final Person person;

  @override
  State<_ApproveDialog> createState() => _ApproveDialogState();
}

class _ApproveDialogState extends State<_ApproveDialog> {
  bool asAdmin = false;
  String? startWith;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return AlertDialog(
      title: Text('Approve ${widget.person.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Maid')),
              ButtonSegment(value: true, label: Text('Admin')),
            ],
            selected: {asAdmin},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => asAdmin = s.first),
          ),
          if (!asAdmin) ...[
            const SizedBox(height: 14),
            DropdownButtonFormField<String?>(
              initialValue: startWith,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Start with tasks from'),
              items: [
                const DropdownMenuItem(value: null, child: Text('No tasks yet')),
                for (final e in scheduleTemplates.entries)
                  DropdownMenuItem(value: 'template:${e.key}', child: Text(e.value)),
                for (final m in state.maidsOn(state.today))
                  DropdownMenuItem(value: 'copy:${m.id}', child: Text("Copy of ${m.name}'s schedule")),
              ],
              onChanged: (v) => setState(() => startWith = v),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () {
            final s = startWith;
            state.approve(
              widget.person,
              asAdmin: asAdmin,
              template: !asAdmin && s != null && s.startsWith('template:') ? s.substring(9) : null,
              copyFrom: !asAdmin && s != null && s.startsWith('copy:') ? s.substring(5) : null,
            );
            Navigator.of(context).pop();
          },
          child: const Text('Approve'),
        ),
      ],
    );
  }
}
