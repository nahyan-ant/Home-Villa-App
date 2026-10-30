import 'package:flutter/material.dart';

import '../app_state.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'task_editor.dart';
import 'team.dart';

/// Admin edits each maid's tasks, day off and who gives which medicines.
class SchedulesPage extends StatefulWidget {
  const SchedulesPage({super.key});

  @override
  State<SchedulesPage> createState() => _SchedulesPageState();
}

class _SchedulesPageState extends State<SchedulesPage> {
  String? selected;

  Future<void> _edit(Task task, {bool isNew = false}) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => TaskEditor(task: task, isNew: isNew)));

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final maids = state.maidsOn(state.today);
    final manage = Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        icon: const Icon(Icons.group_outlined),
        label: const Text('Manage team'),
        onPressed: () =>
            Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TeamScreen())),
      ),
    );
    if (maids.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          SizedBox(height: 40),
          Text(
            'No maids on the team yet. Add one under Manage team.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Palette.muted, fontSize: 15),
          ),
        ],
      );
    }
    final ownerId = maids.any((m) => m.id == selected) ? selected! : maids.first.id;
    final tasks = state.tasksFor(ownerId);
    final dayOff = state.person(ownerId).dayOff;

    final children = <Widget>[
      manage,
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final m in maids)
            ChoiceChip(
              label: Text(m.name),
              labelStyle: TextStyle(
                color: m.id == ownerId ? Palette.white : Palette.text,
                fontFamily: 'DMSans',
                fontWeight: FontWeight.w700,
              ),
              selected: m.id == ownerId,
              showCheckmark: false,
              onSelected: (_) => setState(() => selected = m.id),
            ),
        ],
      ),
      const SizedBox(height: 20),
      const Text('WEEKLY DAY OFF', style: sectionLabel),
      const SizedBox(height: 8),
      DropdownButtonFormField<int?>(
        key: ValueKey('dayoff-$ownerId'),
        initialValue: dayOff,
        isExpanded: true,
        items: [
          const DropdownMenuItem(value: null, child: Text('Not set yet')),
          for (var d = 1; d <= 7; d++) DropdownMenuItem(value: d, child: Text(weekdayNames[d - 1])),
        ],
        onChanged: (d) => state.setDayOff(ownerId, d),
      ),
      if (dayOff != null) ...[const SizedBox(height: 10), DayOffWorkCard(personId: ownerId, weekday: dayOff)],
      if (state.upcomingChanges(ownerId).isNotEmpty) ...[
        const SizedBox(height: 24),
        const Text('UPCOMING CHANGES', style: sectionLabel),
        const SizedBox(height: 8),
        UpcomingChangesCard(ownerId: ownerId, onEdit: (t) => _edit(t.copy())),
      ],
      const SizedBox(height: 24),
      Row(
        children: [
          const Expanded(child: Text('DAILY TASKS', style: sectionLabel)),
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add task'),
            onPressed: () => _edit(
              Task(id: state.newTaskId(), ownerId: ownerId, start: 540, end: 600, title: ''),
              isNew: true,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (final (i, t) in tasks.indexed)
              InkWell(
                onTap: () => _edit(t.copy()),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: i == tasks.length - 1
                        ? null
                        : const Border(bottom: BorderSide(color: Palette.line)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 112,
                        child: Text(
                          timeRange(t.start, t.end),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.title,
                              style: TextStyle(
                                color: t.kind == TaskKind.rest ? Palette.muted : Palette.text,
                                fontSize: 15,
                                fontWeight: t.kind == TaskKind.rest ? FontWeight.w400 : FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [
                                t.kind == TaskKind.medicine && t.dose != null ? t.dose!.label : t.kind.label,
                                if (t.kind != TaskKind.rest) '${t.weight} pt',
                                if (t.days.length < 7) daysLabel(t.days),
                                if (t.extraNote.isNotEmpty) 'Extra on ${daysLabel(t.extraDays)}',
                              ].join(' · '),
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
      const SizedBox(height: 28),
      const Text('MEDICINE DOSES', style: sectionLabel),
      const SizedBox(height: 4),
      const Text(
        'Who gives each dose. Everyone sees when a dose has been given, so it is never repeated.',
        style: TextStyle(color: Palette.muted, fontSize: 13.5, height: 1.4),
      ),
      const SizedBox(height: 10),
      for (final dose in Dose.values) ...[
        DropdownButtonFormField<String?>(
          initialValue: state.doseOwner[dose],
          isExpanded: true,
          decoration: InputDecoration(labelText: dose.label),
          items: [
            const DropdownMenuItem(value: null, child: Text('Whoever is on duty')),
            for (final m in maids) DropdownMenuItem(value: m.id, child: Text(m.name)),
          ],
          onChanged: (id) => state.setDoseOwner(dose, id),
        ),
        const SizedBox(height: 10),
      ],
    ];
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: children);
  }
}

/// Schedule changes that start on a later day, with a way to cancel them.
class UpcomingChangesCard extends StatelessWidget {
  const UpcomingChangesCard({super.key, required this.ownerId, required this.onEdit});

  final String ownerId;
  final ValueChanged<Task> onEdit;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Material(
      color: Palette.butter,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(22),
      child: Column(
        children: [
          for (final c in state.upcomingChanges(ownerId))
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'From ${longDate(c.date)}',
                    style: const TextStyle(color: Palette.muted, fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${c.type.label}: ${c.task.title}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  if (c.type != ChangeType.removed)
                    Text('${timeRange(c.task.start, c.task.end)} · ${daysLabel(c.task.days)}', style: bodyMuted),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (c.type != ChangeType.removed)
                        TextButton(onPressed: () => onEdit(c.task), child: const Text('Edit')),
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: Palette.alert),
                        onPressed: () => state.cancelChange(c),
                        child: const Text('Cancel change'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Switch on one of the next four days off for an event.
class DayOffWorkCard extends StatelessWidget {
  const DayOffWorkCard({super.key, required this.personId, required this.weekday});

  final String personId;
  final int weekday;

  Future<DayOffWork?> _ask(BuildContext context, DateTime day) => showDialog<DayOffWork>(
    context: context,
    builder: (_) => _WorkDialog(
      title: '${AppScope.of(context).person(personId).name} works on ${shortDate(day)}',
    ),
  );

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final today = state.today;
    final first = today.add(Duration(days: (weekday - today.weekday) % 7));
    final days = [for (var w = 0; w < 4; w++) first.add(Duration(days: 7 * w))];
    return Material(
      color: Palette.white,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Text(
              'Work on a day off (for an event)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          for (final day in days)
            Builder(
              builder: (context) {
                final work = state.dayOffWorkOn(personId, day);
                return SwitchListTile(
                  value: work != null,
                  title: Text(shortDate(day), style: const TextStyle(fontSize: 15)),
                  subtitle: Text(
                    work == null
                        ? 'Day off'
                        : 'Working. ${work.compensation.label}${work.note.isEmpty ? '' : ' · ${work.note}'}',
                  ),
                  onChanged: (on) async {
                    if (!on) {
                      state.setDayOffWork(personId, day, null);
                      return;
                    }
                    final chosen = await _ask(context, day);
                    if (chosen != null) state.setDayOffWork(personId, day, chosen);
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}

class _WorkDialog extends StatefulWidget {
  const _WorkDialog({required this.title});

  final String title;

  @override
  State<_WorkDialog> createState() => _WorkDialogState();
}

class _WorkDialogState extends State<_WorkDialog> {
  Compensation compensation = Compensation.dayOff;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Compensation', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SegmentedButton<Compensation>(
          segments: [
            for (final c in Compensation.values) ButtonSegment(value: c, label: Text(c.label)),
          ],
          selected: {compensation},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => compensation = s.first),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _note,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Note (optional)',
            hintText: 'For example: family lunch, 20 guests',
          ),
        ),
      ],
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
        onPressed: () => Navigator.of(context).pop(DayOffWork(compensation, _note.text.trim())),
        child: const Text('Switch on'),
      ),
    ],
  );
}
