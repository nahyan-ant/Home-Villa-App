import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../format.dart';
import '../hindi.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

Future<void> openTaskSheet(BuildContext context, Task task, DateTime day, bool adminView) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => TaskSheet(task: task, day: day, adminView: adminView),
    );

/// Opens the camera; returns the photo, or null if cancelled.
Future<Uint8List?> takePhoto() async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.camera,
    preferredCameraDevice: CameraDevice.rear,
    maxWidth: 1600,
    imageQuality: 80,
  );
  return picked?.readAsBytes();
}

/// Everything about one task. A task only counts as done with a photo as
/// proof; each medicine dose needs its own photo too.
class TaskSheet extends StatefulWidget {
  const TaskSheet({super.key, required this.task, required this.day, required this.adminView});

  final Task task;
  final DateTime day;
  final bool adminView;

  @override
  State<TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<TaskSheet> {
  final Map<Parent, Map<String, TextEditingController>> readings = {
    for (final p in Parent.values)
      p: {for (final f in ['sys', 'dia', 'sugar', 'oxygen']) f: TextEditingController()},
  };
  final List<Uint8List> photos = [];
  final note = TextEditingController();
  bool _noteLoaded = false;
  bool _busy = false;

  Task get task => widget.task;
  DateTime get day => widget.day;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_noteLoaded) {
      note.text = AppScope.of(context).noteFor(task, day)?.text ?? '';
      _noteLoaded = true;
    }
  }

  @override
  void dispose() {
    for (final fields in readings.values) {
      for (final c in fields.values) {
        c.dispose();
      }
    }
    note.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final bytes = await takePhoto();
    if (bytes != null && mounted) setState(() => photos.add(bytes));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final tick = state.tickFor(task, day);
    final mine = !widget.adminView;
    final children = <Widget>[
      Text(
        timeRange(task.start, task.end),
        style: const TextStyle(color: Palette.muted, fontSize: 14, fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 4),
      Text(task.title, style: const TextStyle(fontFamily: 'DMSerifDisplay', fontSize: 26, height: 1.15)),
      HindiLine(task.title, size: 19, color: Palette.text),
      if (task.details.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(task.details, style: const TextStyle(color: Palette.muted, fontSize: 15, height: 1.4)),
        HindiLine(task.details, size: 15),
      ],
      if (task.extraNote.isNotEmpty && task.extraDays.contains(day.weekday)) ...[
        const SizedBox(height: 8),
        Text(
          '${slashDays(task.extraDays)}: ${tr(task.extraNote)}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, height: 1.4),
        ),
      ],
      if (mine && task.ownerId != state.user?.id) ...[
        const SizedBox(height: 8),
        Text(
          "Covering ${state.person(task.ownerId).name}'s task after the night emergency.",
          style: const TextStyle(color: Palette.amber, fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ],
      const SizedBox(height: 6),
      Text(
        bi(
          'Counts for ${task.weight} ${task.weight == 1 ? 'point' : 'points'} of the day.',
          'दिन के ${task.weight} अंक।',
        ),
        style: bodyMuted,
      ),
      const SizedBox(height: 20),
      if (task.kind == TaskKind.medicine) ..._medicines(state),
      if (task.kind == TaskKind.vitals) ..._vitals(tick),
      ..._photos(tick),
      ..._note(state),
    ];
    if (tick != null) {
      children.addAll([
        _DoneBox(tick: tick, task: task),
        if (!tick.sent) const PendingNote(),
        if (mine) ...[
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: state.canUndo(task, day) ? () => state.undoTick(task, day) : null,
            child: Text(tr1('Undo')),
          ),
          if (!state.canUndo(task, day) && tick.byId == state.user?.id)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                tr('This was already sent. Undo it when the internet is back.'),
                textAlign: TextAlign.center,
                style: bodyMuted,
              ),
            ),
        ],
      ]);
    } else if (!mine) {
      final missed = state.stateOf(task, day) == TaskState.missed;
      children.add(
        Text(
          missed ? 'Missed: no photo by ${clock(task.end)}' : 'Not done yet',
          style: TextStyle(
            color: missed ? Palette.alert : Palette.muted,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    } else {
      children.addAll([
        _doneButton(state),
        const SizedBox(height: 8),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Palette.alert),
          onPressed: () => _notDone(state),
          child: Text(tr1("I couldn't do this task")),
        ),
      ]);
    }
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    );
  }

  bool _dosesDone(AppState state) {
    final dose = task.dose;
    return dose != null && Parent.values.every((p) => state.doseRecord(dose, p, day) != null);
  }

  Widget _doneButton(AppState state) {
    final entered = _readings();
    final String? missing = switch (task.kind) {
      TaskKind.medicine when photos.isEmpty && !_dosesDone(state) => tr('Record each dose with a photo first.'),
      TaskKind.vitals when entered.isEmpty => tr('Enter the readings and add a photo.'),
      _ when photos.isEmpty && task.kind != TaskKind.medicine => tr('Add a photo as proof first.'),
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (missing != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(missing, textAlign: TextAlign.center, style: bodyMuted),
          ),
        FilledButton(
          onPressed: missing != null || _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  await state.tick(task, day, photos: photos, vitals: entered);
                  if (mounted) Navigator.of(context).pop();
                },
          child: Text(tr1(task.kind == TaskKind.vitals ? 'Save readings' : 'Mark done')),
        ),
      ],
    );
  }

  Future<void> _notDone(AppState state) async {
    final reason = await showDialog<String>(context: context, builder: (_) => const _ReasonDialog());
    if (reason == null || !mounted) return;
    state.notDone(task, day, reason);
    Navigator.of(context).pop();
  }

  // ------------------------------------------------------------ medicines

  List<Widget> _medicines(AppState state) {
    final dose = task.dose;
    if (dose == null) return const [];
    final owner = state.doseOwner[dose];
    final me = state.user!;
    return [
      Text(tr1(dose.label).toUpperCase(), style: sectionLabel),
      const SizedBox(height: 6),
      if (owner != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            owner == me.id
                ? tr('You are responsible for this dose.')
                : bi(
                    '${state.person(owner).name} is responsible for this dose. Only give it if you are asked to.',
                    'यह दवाई ${state.person(owner).name} देगी। कहा जाए तभी दें।',
                  ),
            style: const TextStyle(fontSize: 14, height: 1.35),
          ),
        ),
      for (final parent in Parent.values) _parentDose(state, dose, parent),
      const SizedBox(height: 8),
      if (state.online || widget.adminView)
        Text(
          tr('Take a photo of the medicine for each dose. Everyone sees who gave it, so it is never given twice.'),
          style: bodyMutedTall,
        )
      else
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Palette.alertLight,
            border: Border.all(color: Palette.alert),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.wifi_off, size: 20, color: Palette.alert),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr('No internet: you cannot see if someone else already gave this dose. Ask the others before giving it.'),
                  style: const TextStyle(color: Palette.alert, fontSize: 14, fontWeight: FontWeight.w700, height: 1.35),
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 20),
    ];
  }

  Widget _parentDose(AppState state, Dose dose, Parent parent) {
    final record = state.doseRecord(dose, parent, day);
    final given = record != null;
    final byMe = given && record.byId == state.user?.id;
    final status = given
        ? bi(
            'Given at ${clockOf(record.time)} by ${byMe ? 'you' : state.person(record.byId).name}'
            '${record.sent ? '' : ' (not sent yet)'}',
            '${clockOf(record.time)} बजे ${byMe ? 'आपने' : '${state.person(record.byId).name} ने'} दी',
          )
        : tr('Not given yet');
    final photo = record?.photo;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        border: Border.all(color: given ? Palette.line : Palette.ink, width: given ? 1 : 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr1(parent.label), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(status, style: TextStyle(color: given ? Palette.text : Palette.muted, fontSize: 14)),
                if (given && !byMe && !widget.adminView)
                  Text(
                    tr('Already given. Do not give again.'),
                    style: const TextStyle(color: Palette.alert, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
              ],
            ),
          ),
          if (photo != null) ...[
            PhotoThumb(photo: photo, size: 48, onOpen: () => openPhotos(context, [photo], 0)),
            const SizedBox(width: 8),
          ],
          if (!given && !widget.adminView)
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: Text(tr1('Given')),
              onPressed: () async {
                final bytes = await takePhoto();
                if (bytes != null) await state.giveDose(dose, parent, day, bytes);
              },
            )
          else if (given)
            const Icon(Icons.check_circle, color: Palette.ink),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- vitals

  Map<Parent, Vitals> _readings() {
    num? read(TextEditingController c) => num.tryParse(c.text.trim());
    final result = <Parent, Vitals>{};
    for (final p in Parent.values) {
      final f = readings[p]!;
      final v = Vitals(read(f['sys']!), read(f['dia']!), read(f['sugar']!), read(f['oxygen']!));
      if (v.sys != null || v.dia != null || v.sugar != null || v.oxygen != null) result[p] = v;
    }
    return result;
  }

  List<Widget> _vitals(Tick? tick) {
    final privacy = PrivacyNote(tr('Only you and admin can see these readings.'));
    if (tick != null) {
      return [
        for (final e in tick.vitals.entries) ...[
          Text(e.key.label.toUpperCase(), style: sectionLabel),
          const SizedBox(height: 4),
          Text(e.value.summary(), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
          const SizedBox(height: 14),
        ],
        privacy,
        const SizedBox(height: 16),
      ];
    }
    if (widget.adminView) return const [];
    return [
      for (final p in Parent.values) ...[
        Text(tr1(p.label).toUpperCase(), style: sectionLabel),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _number(readings[p]!['sys']!, tr1('BP top'))),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('/', style: TextStyle(fontSize: 20)),
            ),
            Expanded(child: _number(readings[p]!['dia']!, tr1('BP bottom'))),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _number(readings[p]!['sugar']!, tr1('Blood sugar'), 'mg/dL')),
            const SizedBox(width: 10),
            Expanded(child: _number(readings[p]!['oxygen']!, tr1('Oxygen'), '%')),
          ],
        ),
        const SizedBox(height: 18),
      ],
      privacy,
      const SizedBox(height: 16),
    ];
  }

  Widget _number(TextEditingController controller, String label, [String? suffix]) => TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    textInputAction: TextInputAction.next,
    decoration: InputDecoration(labelText: label, suffixText: suffix),
    onChanged: (_) => setState(() {}),
  );

  // --------------------------------------------------------------- photos

  List<Widget> _photos(Tick? tick) {
    final List<Photo> shown = tick?.photos ??
        [for (final (i, b) in photos.indexed) Photo(path: 'new-$i', label: '${task.title}, photo ${i + 1}', bytes: b)];
    final editable = tick == null && !widget.adminView;
    return [
      Text(tr1(task.kind == TaskKind.medicine ? 'MORE PHOTOS (OPTIONAL)' : 'PHOTO PROOF'), style: sectionLabel),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Palette.text, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            const Icon(Icons.no_photography_outlined, size: 22, color: Palette.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tr(
                  'Never take photos in bedrooms or bathrooms, and never of Mama or Papa. '
                  'For care tasks, photo the tray, meal, clothes or medicine instead.',
                ),
                style: const TextStyle(color: Palette.white, fontSize: 14.5, fontWeight: FontWeight.w500, height: 1.35),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      if (shown.isNotEmpty) ...[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (i, photo) in shown.indexed)
              PhotoThumb(
                photo: photo,
                size: 88,
                onRemove: editable ? () => setState(() => photos.removeAt(i)) : null,
                onOpen: () => openPhotos(context, shown, i),
              ),
          ],
        ),
        const SizedBox(height: 14),
      ],
      if (editable) ...[
        OutlinedButton.icon(
          onPressed: _addPhoto,
          icon: const Icon(Icons.photo_camera_outlined),
          label: Text(tr1(photos.isEmpty ? 'Take photo' : 'Add another photo')),
        ),
        const SizedBox(height: 10),
      ],
      PrivacyNote(tr('Only you and admin can see these photos.')),
      const SizedBox(height: 16),
    ];
  }

  // ----------------------------------------------------------------- note

  List<Widget> _note(AppState state) {
    final saved = state.noteFor(task, day);
    if (widget.adminView) {
      return saved == null ? const [] : [NoteView(saved), const SizedBox(height: 16)];
    }
    final text = note.text.trim();
    final Widget below;
    if (text != (saved?.text ?? '')) {
      below = Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () {
            state.saveNote(task, day, note.text);
            FocusScope.of(context).unfocus();
          },
          child: Text(tr1(text.isEmpty ? 'Remove note' : 'Save note')),
        ),
      );
    } else if (saved != null) {
      below = Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          'Saved ${clockOf(saved.time)}${saved.sent ? '. Admin can see it.' : ' on this phone, not sent yet.'}',
          style: const TextStyle(color: Palette.muted, fontSize: 12.5),
        ),
      );
    } else {
      below = const SizedBox.shrink();
    }
    return [
      TextField(
        controller: note,
        minLines: 1,
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: tr1('Note (optional)'),
          hintText: 'For example: Papa refused his medicine',
          prefixIcon: const Icon(Icons.sticky_note_2_outlined, size: 20),
        ),
        onChanged: (_) => setState(() {}),
      ),
      AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: below),
      const SizedBox(height: 16),
    ];
  }
}

class _DoneBox extends StatelessWidget {
  const _DoneBox({required this.tick, required this.task});

  final Tick tick;
  final Task task;

  @override
  Widget build(BuildContext context) {
    final by = AppScope.of(context).person(tick.byId).name;
    final late = minuteOfDay(tick.time) > task.end ? ' (late)' : '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tick.done ? Palette.butter : Palette.alertLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(tick.done ? Icons.check_circle : Icons.cancel_outlined, color: tick.done ? Palette.ink : Palette.alert),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tick.done
                  ? bi('Done at ${clockOf(tick.time)} by $by$late', '${clockOf(tick.time)} बजे $by ने पूरा किया')
                  : 'Not done. $by at ${clockOf(tick.time)}: ${tick.reason.isEmpty ? 'no reason given' : tick.reason}',
              style: TextStyle(
                color: tick.done ? Palette.text : Palette.alert,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog();

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tr1("Couldn't do it")),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('It still counts as missed. Say why, so admin knows.'), style: bodyMutedTall),
        const SizedBox(height: 12),
        TextField(
          controller: _reason,
          autofocus: true,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: tr1('Why?'), hintText: 'For example: Mama was sleeping'),
          onChanged: (_) => setState(() {}),
        ),
      ],
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(tr1('Cancel'))),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
        onPressed: _reason.text.trim().isEmpty ? null : () => Navigator.of(context).pop(_reason.text.trim()),
        child: Text(tr1('Save')),
      ),
    ],
  );
}
