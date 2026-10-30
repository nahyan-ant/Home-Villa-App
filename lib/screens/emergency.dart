import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../format.dart';
import '../models.dart';
import '../outbox.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// What to do in an emergency, who to call, and the night-emergency log.
class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final isAdmin = state.user?.isAdmin == true;
    final covers = [
      for (final d in {state.today, state.coverDay}) ...?state.covers[dayKey(d)]?.values,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(
            children: [
              const Expanded(child: Text('CALL', style: sectionLabel)),
              if (isAdmin)
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add number'),
                  onPressed: () => _editContact(context, state, null),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final c in state.contacts)
                  ListTile(
                    leading: const Icon(Icons.call, color: Palette.alert),
                    title: Text(c.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(c.phone),
                    trailing: isAdmin
                        ? IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            tooltip: 'Edit ${c.label}',
                            onPressed: () => _editContact(context, state, c),
                          )
                        : null,
                    onTap: () => launchUrl(Uri(scheme: 'tel', path: c.phone.replaceAll(' ', ''))),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(child: Text('WHAT TO DO', style: sectionLabel)),
              if (isAdmin)
                TextButton.icon(
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                  onPressed: () => _editSop(context, state),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Palette.white, borderRadius: BorderRadius.circular(22)),
            child: Text(state.sop, style: const TextStyle(fontSize: 15, height: 1.5)),
          ),
          const SizedBox(height: 12),
          const InfoBanner(
            icon: Icons.chat_outlined,
            text: 'If the app is not working, post the photos in the family WhatsApp group with the time and task.',
          ),
          const SizedBox(height: 24),
          const Text('NIGHT EMERGENCY', style: sectionLabel),
          const SizedBox(height: 4),
          const Text(
            'If someone was up at night with an emergency, the other maid covers her morning tasks so she can rest.',
            style: bodyMutedTall,
          ),
          const SizedBox(height: 10),
          for (final c in covers)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                decoration: BoxDecoration(color: Palette.butter, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${shortDate(c.day)}: ${state.person(c.coveringId).name} covers '
                        '${state.person(c.restingId).name} until ${clock(c.untilMin)}'
                        '${c.note.isEmpty ? '' : '\n${c.note}'}',
                        style: const TextStyle(fontSize: 14, height: 1.35),
                      ),
                    ),
                    if (isAdmin || c.loggedBy == state.user?.id)
                      TextButton(onPressed: () => state.cancelCover(c), child: const Text('Cancel')),
                  ],
                ),
              ),
            ),
          OutlinedButton.icon(
            icon: const Icon(Icons.bedtime_outlined),
            label: const Text('Log a night emergency'),
            onPressed: () => showDialog<void>(context: context, builder: (_) => _NightDialog(state: state)),
          ),
        ],
      ),
    );
  }

  Future<void> _editSop(BuildContext context, AppState state) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _TextDialog(title: 'What to do', initial: state.sop, lines: 12),
    );
    if (text != null) state.saveSop(text);
  }

  Future<void> _editContact(BuildContext context, AppState state, Contact? c) => showDialog<void>(
    context: context,
    builder: (_) => _ContactDialog(state: state, contact: c),
  );
}

class _NightDialog extends StatefulWidget {
  const _NightDialog({required this.state});

  final AppState state;

  @override
  State<_NightDialog> createState() => _NightDialogState();
}

class _NightDialogState extends State<_NightDialog> {
  late final maids = widget.state.maidsOn(widget.state.today);
  late String? resting = widget.state.user?.isAdmin == false ? widget.state.user!.id : maids.firstOrNull?.id;
  String? covering;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final others = maids.where((m) => m.id != resting).toList();
    if (!others.any((m) => m.id == covering)) covering = others.firstOrNull?.id;
    return AlertDialog(
      title: const Text('Night emergency'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'For the morning of ${longDate(widget.state.coverDay)}, until 12:00 PM.',
            style: bodyMutedTall,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: resting,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Who was up and rests'),
            items: [for (final m in maids) DropdownMenuItem(value: m.id, child: Text(m.name))],
            onChanged: (id) => setState(() => resting = id),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey(resting),
            initialValue: covering,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Who covers the morning'),
            items: [for (final m in others) DropdownMenuItem(value: m.id, child: Text(m.name))],
            onChanged: (id) => setState(() => covering = id),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'What happened', hintText: 'For example: Papa had a fever at 2 AM'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: resting == null || covering == null
              ? null
              : () {
                  widget.state.logNightEmergency(restingId: resting!, coveringId: covering!, note: _note.text.trim());
                  Navigator.of(context).pop();
                },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ContactDialog extends StatefulWidget {
  const _ContactDialog({required this.state, this.contact});

  final AppState state;
  final Contact? contact;

  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  late final _label = TextEditingController(text: widget.contact?.label ?? '');
  late final _phone = TextEditingController(text: widget.contact?.phone ?? '');

  @override
  void dispose() {
    _label.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.contact;
    return AlertDialog(
      title: Text(c == null ? 'Add number' : 'Edit number'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _label,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Who', hintText: 'For example: Family doctor'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone number'),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        if (c != null)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Palette.alert),
            onPressed: () {
              widget.state.deleteContact(c);
              Navigator.of(context).pop();
            },
            child: const Text('Remove'),
          ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: _label.text.trim().isEmpty || _phone.text.trim().isEmpty
              ? null
              : () {
                  widget.state.saveContact(
                    Contact(
                      id: c?.id ?? newUuid(),
                      label: _label.text.trim(),
                      phone: _phone.text.trim(),
                      sort: c?.sort ?? widget.state.contacts.length + 1,
                    ),
                  );
                  Navigator.of(context).pop();
                },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _TextDialog extends StatefulWidget {
  const _TextDialog({required this.title, required this.initial, this.lines = 4});

  final String title;
  final String initial;
  final int lines;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(controller: _text, maxLines: widget.lines, textCapitalization: TextCapitalization.sentences),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
        onPressed: () => Navigator.of(context).pop(_text.text.trim()),
        child: const Text('Save'),
      ),
    ],
  );
}
