import 'package:flutter/material.dart';

import '../app_state.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Add or change a task. Changes start on a chosen day; earlier days keep the
/// old version.
class TaskEditor extends StatefulWidget {
  const TaskEditor({super.key, required this.task, required this.isNew});

  /// A copy, edited in place and saved as a new version.
  final Task task;
  final bool isNew;

  @override
  State<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<TaskEditor> {
  late final _title = TextEditingController(text: widget.task.title);
  late final _details = TextEditingController(text: widget.task.details);
  late final _extra = TextEditingController(text: widget.task.extraNote);

  /// The first day of the change, once picked.
  DateTime? _from;

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    _extra.dispose();
    super.dispose();
  }

  Task get task => widget.task;

  /// Picked day, else a future start the version already has, else today.
  DateTime _startDay(AppState state) {
    if (_from != null) return _from!;
    final from = task.validFrom;
    if (from != null && from.isAfter(state.today)) return from;
    return state.today;
  }

  Future<void> _pickStart(AppState state) async {
    final today = state.today;
    final picked = await showDatePicker(
      context: context,
      firstDate: today,
      lastDate: DateTime(today.year, today.month, today.day + 90),
      initialDate: _startDay(state),
      helpText: 'Change starts from',
    );
    if (picked != null) setState(() => _from = picked);
  }

  String _explain(AppState state, {required bool removing}) {
    final from = _startDay(state);
    final name = state.person(task.ownerId).name;
    if (from == state.today) {
      return removing
          ? "It comes off $name's checklist today. Earlier days keep it."
          : "$name's checklist changes today. Earlier days stay as they were.";
    }
    final dayBefore = DateTime(from.year, from.month, from.day - 1);
    return removing
        ? "It stays on $name's checklist until ${shortDate(dayBefore)}, then comes off from ${shortDate(from)}."
        : "$name's checklist stays as it is until then. The new version starts on ${shortDate(from)}.";
  }

  Future<void> _pickTime({required bool start}) async {
    final minutes = start ? task.start : task.end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked == null) return;
    final chosen = picked.hour * 60 + picked.minute;
    setState(() {
      if (start) {
        final length = task.end - task.start;
        task.start = chosen;
        // Moving the start keeps the task's length.
        if (task.end <= chosen) task.end = chosen + (length > 0 ? length : 30);
      } else {
        task.end = chosen;
      }
    });
  }

  String? get _problem {
    if (_title.text.trim().isEmpty) return 'Give the task a name.';
    if (task.end <= task.start) return 'The end time must be after the start time.';
    if (task.days.isEmpty) return 'Choose at least one day.';
    if (task.kind == TaskKind.medicine && task.dose == null) return 'Choose which medicine dose.';
    return null;
  }

  void _save(AppState state) {
    task
      ..title = _title.text.trim()
      ..details = _details.text.trim()
      ..extraNote = _extra.text.trim();
    if (task.kind != TaskKind.medicine) task.dose = null;
    final from = _startDay(state);
    state.saveTask(task, from);
    if (from != state.today) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved. It starts on ${shortDate(from)}.'), duration: const Duration(seconds: 4)),
      );
    }
    Navigator.of(context).pop();
  }

  Future<void> _remove(AppState state) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this task?'),
        content: Text('"${task.title}": ${_explain(state, removing: true)}'),
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
    if (sure == true && mounted) {
      state.removeTask(task.seriesId, _startDay(state));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final problem = _problem;
    final from = _startDay(state);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'New task for ${state.person(task.ownerId).name}' : 'Edit task'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Task'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _details,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Details'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _TimeField(label: 'Start', minutes: task.start, onTap: () => _pickTime(start: true))),
              const SizedBox(width: 12),
              Expanded(child: _TimeField(label: 'End', minutes: task.end, onTap: () => _pickTime(start: false))),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<TaskKind>(
            initialValue: task.kind,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'How it is ticked'),
            items: [for (final k in TaskKind.values) DropdownMenuItem(value: k, child: Text(k.label))],
            onChanged: (k) => setState(() {
              // Keep a custom weight; otherwise follow the new kind.
              if (task.weight == Task.defaultWeight(task.kind)) task.weight = Task.defaultWeight(k!);
              task.kind = k!;
            }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey('weight-${task.kind}'),
            initialValue: task.weight,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Weightage',
              helperText: 'Points this task is worth. Missing it takes them off the day.',
            ),
            items: [
              for (var w = 0; w <= 5; w++)
                DropdownMenuItem(value: w, child: Text(w == 0 ? '0 (not scored)' : '$w ${w == 1 ? 'point' : 'points'}')),
            ],
            onChanged: (w) => setState(() => task.weight = w!),
          ),
          if (task.kind == TaskKind.medicine) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<Dose>(
              initialValue: task.dose,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Medicine dose'),
              items: [for (final d in Dose.values) DropdownMenuItem(value: d, child: Text(d.label))],
              onChanged: (d) => setState(() => task.dose = d),
            ),
          ],
          const SizedBox(height: 20),
          const Text('DAYS', style: sectionLabel),
          const SizedBox(height: 8),
          DayChips(days: task.days, onChanged: () => setState(() {})),
          const SizedBox(height: 20),
          const Text('EXTRA DETAILS ON SOME DAYS', style: sectionLabel),
          const SizedBox(height: 8),
          TextField(
            controller: _extra,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Extra details (optional)',
              hintText: 'For example: Mama is out at physiotherapy',
            ),
          ),
          const SizedBox(height: 8),
          DayChips(days: task.extraDays, onChanged: () => setState(() {})),
          const SizedBox(height: 20),
          const Text('STARTS FROM', style: sectionLabel),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _pickStart(state),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'First day of the change',
                suffixIcon: Icon(Icons.calendar_today_outlined, size: 20),
              ),
              child: Text(
                from == state.today ? 'Today, ${shortDate(from)}' : longDate(from),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(_explain(state, removing: false), style: bodyMutedTall),
          const SizedBox(height: 28),
          if (problem != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(problem, style: const TextStyle(color: Palette.alert, fontSize: 14)),
            ),
          FilledButton(onPressed: problem == null ? () => _save(state) : null, child: const Text('Save')),
          if (!widget.isNew) ...[
            const SizedBox(height: 10),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Palette.alert),
              onPressed: () => _remove(state),
              child: const Text('Remove task'),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({required this.label, required this.minutes, required this.onTap});

  final String label;
  final int minutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: onTap,
    child: InputDecorator(
      decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.schedule, size: 20)),
      child: Text(clock(minutes), style: const TextStyle(fontSize: 16)),
    ),
  );
}

/// Mon to Sun as chips that switch on and off.
class DayChips extends StatelessWidget {
  const DayChips({super.key, required this.days, required this.onChanged});

  final Set<int> days;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (var d = 1; d <= 7; d++)
        FilterChip(
          label: Text(weekdayShort[d - 1]),
          labelStyle: TextStyle(color: days.contains(d) ? Palette.white : Palette.text),
          selected: days.contains(d),
          showCheckmark: false,
          onSelected: (on) {
            on ? days.add(d) : days.remove(d);
            onChanged();
          },
        ),
    ],
  );
}
