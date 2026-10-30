import 'package:flutter/material.dart';

import '../app_state.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import 'checklist.dart';

/// Admin looks at one maid's day and confirms it or sends it back.
class MaidDayScreen extends StatelessWidget {
  const MaidDayScreen({super.key, required this.maid, required this.day});

  final Person maid;
  final DateTime day;

  Future<void> _sendBack(BuildContext context, AppState state) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _SendBackDialog(name: maid.name),
    );
    if (note != null) state.setReview(maid.id, day, ReviewStatus.sentBack, note);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final review = state.reviewOf(maid.id, day);
    final off = state.isDayOff(maid.id, day);

    Widget? bar;
    if (!off) {
      final Widget content;
      if (review == null) {
        content = Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: () => _sendBack(context, state), child: const Text('Send back')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  state.setReview(maid.id, day, ReviewStatus.confirmed);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("${maid.name}'s day confirmed"), duration: const Duration(seconds: 4)),
                  );
                },
                child: const Text('Confirm day'),
              ),
            ),
          ],
        );
      } else {
        final by = state.person(review.byId).name;
        final at = clockOf(review.time);
        final sentBack = review.status == ReviewStatus.sentBack;
        content = Row(
          children: [
            Expanded(
              child: Text(
                sentBack ? 'Sent back by $by at $at' : 'Confirmed by $by at $at',
                style: TextStyle(
                  color: sentBack ? Palette.alert : Palette.text,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(onPressed: () => state.setReview(maid.id, day, null), child: const Text('Change')),
          ],
        );
      }
      bar = SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Palette.white,
            border: Border(top: BorderSide(color: Palette.line)),
          ),
          child: content,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('${maid.name} · ${shortDate(day)}')),
      body: Checklist(personId: maid.id, day: day, adminView: true),
      bottomNavigationBar: bar,
    );
  }
}

class _SendBackDialog extends StatefulWidget {
  const _SendBackDialog({required this.name});

  final String name;

  @override
  State<_SendBackDialog> createState() => _SendBackDialogState();
}

class _SendBackDialogState extends State<_SendBackDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text("Send back ${widget.name}'s day"),
    content: TextField(
      controller: _note,
      autofocus: true,
      maxLines: 3,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        labelText: 'What needs fixing?',
        hintText: 'For example: please add a photo of the living room',
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
        onPressed: () => Navigator.of(context).pop(_note.text.trim()),
        child: const Text('Send back'),
      ),
    ],
  );
}
