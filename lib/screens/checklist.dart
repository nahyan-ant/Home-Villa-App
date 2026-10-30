import 'package:flutter/material.dart';

import '../app_state.dart';
import '../format.dart';
import '../models.dart';
import '../push/push.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'task_sheet.dart';

/// One maid's tasks for one day, in time order.
///
/// Maids see their own day and tick it; admin sees the same list read-only.
class Checklist extends StatelessWidget {
  const Checklist({
    super.key,
    required this.personId,
    required this.day,
    required this.adminView,
    this.onOpenShopping,
  });

  final String personId;
  final DateTime day;
  final bool adminView;
  final VoidCallback? onOpenShopping;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final tasks = state.tasksOn(personId, day);
    if (state.isDayOff(personId, day)) {
      return DayOffView(personId: personId, day: day, adminView: adminView);
    }
    final waiting = state.waitingToSend;
    final children = <Widget>[
      AnimatedSize(
        alignment: Alignment.topCenter,
        curve: Curves.easeOut,
        duration: const Duration(milliseconds: 260),
        child: !adminView && !state.online
            ? Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: InfoBanner(
                  icon: Icons.wifi_off,
                  text:
                      'No internet. Keep ticking: everything is saved on this phone and sent when '
                      'the internet is back.${waiting > 0 ? ' $waiting waiting to send.' : ''}',
                ),
              )
            : const SizedBox(width: double.infinity),
      ),
      if (!adminView && day == state.today) ReminderBanners(personId: personId),
      Stagger(index: 0, child: DaySummary(personId: personId, day: day, canLog: !adminView && day == state.today)),
    ];
    for (final (i, task) in tasks.indexed) {
      children.add(
        Stagger(
          index: i + 1,
          child: TaskCard(
            task: task,
            day: day,
            onTap: () => openTaskSheet(context, task, day, adminView),
            coveringFor: task.ownerId == personId ? null : state.person(task.ownerId).name,
            onOpenShopping: onOpenShopping,
          ),
        ),
      );
    }
    return ListView(padding: const EdgeInsets.only(bottom: 32), children: children);
  }
}

/// Progress ring, review result and day-off work for the day.
class DaySummary extends StatelessWidget {
  const DaySummary({super.key, required this.personId, required this.day, this.canLog = false});

  final String personId;
  final DateTime day;

  /// The maid's own today: she can start and end breaks here.
  final bool canLog;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final progress = state.progress(personId, day);
    final review = state.reviewOf(personId, day);
    final work = state.dayOffWorkOn(personId, day);
    final current = state.currentTask(personId, day);
    final share = progress.total == 0 ? 0.0 : progress.done / progress.total;

    final children = <Widget>[
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Palette.white, borderRadius: BorderRadius.circular(28)),
        child: Row(
          children: [
            ProgressRing(
              value: share,
              size: 76,
              child: Text(
                '${(share * 100).round()}%',
                style: const TextStyle(fontFamily: 'DMSerifDisplay', fontSize: 19),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    longDate(day).toUpperCase(),
                    style: const TextStyle(
                      color: Palette.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${progress.done} of ${progress.total} done',
                    style: const TextStyle(fontFamily: 'DMSerifDisplay', fontSize: 28, height: 1.1),
                  ),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      children: [
                        if (progress.missed > 0)
                          TextSpan(
                            text: '${progress.missed} missed',
                            style: const TextStyle(color: Palette.alert, fontWeight: FontWeight.w700),
                          ),
                        if (progress.missed > 0 && current != null) const TextSpan(text: ' · '),
                        if (current != null) TextSpan(text: 'Now: ${current.title}'),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Palette.muted, fontSize: 13.5, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Score ${(progress.score * 100).round()}%'
                    '${progress.weightLost > 0 ? ' (\u2212${(progress.weightLost * 100 / progress.weightTotal).round()}% for missed tasks)' : ''}',
                    style: TextStyle(
                      color: progress.weightLost > 0 ? Palette.alert : Palette.text,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ];
    final phase = state.phaseOf(personId);
    if (phase != Phase.none) {
      children.addAll([
        const SizedBox(height: 14),
        InfoBanner(
          icon: Icons.report_outlined,
          text: '${phase.label}: too many missed tasks recently '
              '(${state.missesIn(personId, 7)} in the last 7 days). Every task needs a photo on time.',
          alert: true,
        ),
      ]);
    }
    final resting = state.coverFor(personId, day);
    if (resting != null) {
      children.addAll([
        const SizedBox(height: 14),
        InfoBanner(
          icon: Icons.bedtime_outlined,
          text: 'Rest after the night emergency. ${state.person(resting.coveringId).name} does your tasks '
              'until ${clock(resting.untilMin)}.',
        ),
      ]);
    }
    for (final c in state.coveredBy(personId, day)) {
      children.addAll([
        const SizedBox(height: 14),
        InfoBanner(
          icon: Icons.volunteer_activism_outlined,
          text: 'You cover ${state.person(c.restingId).name}\'s tasks until ${clock(c.untilMin)} '
              'after the night emergency. They are in your list below.',
        ),
      ]);
    }
    if (canLog) children.addAll([const SizedBox(height: 14), TimeLogCard(personId: personId)]);
    if (work != null) {
      children.addAll([
        const SizedBox(height: 14),
        InfoBanner(
          icon: Icons.event_outlined,
          text:
              'Working on your day off. Compensation: ${work.compensation.label}.'
              '${work.note.isEmpty ? '' : ' ${work.note}'}',
        ),
      ]);
    }
    Widget reviewBanner = const SizedBox(width: double.infinity);
    if (review != null) {
      final by = state.person(review.byId).name;
      final at = clockOf(review.time);
      reviewBanner = Padding(
        padding: const EdgeInsets.only(top: 14),
        child: review.status == ReviewStatus.confirmed
            ? InfoBanner(icon: Icons.verified_outlined, text: 'Day confirmed by $by at $at.')
            : InfoBanner(
                icon: Icons.undo,
                text: 'Sent back by $by at $at${review.note.isEmpty ? '.' : ': ${review.note}'}',
                alert: true,
              ),
      );
    }
    children.add(
      AnimatedSize(
        alignment: Alignment.topCenter,
        curve: Curves.easeOut,
        duration: const Duration(milliseconds: 260),
        child: reviewBanner,
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class DayOffView extends StatelessWidget {
  const DayOffView({super.key, required this.personId, required this.day, required this.adminView});

  final String personId;
  final DateTime day;
  final bool adminView;

  @override
  Widget build(BuildContext context) {
    final name = AppScope.of(context).person(personId).name;
    final weekday = weekdayNames[day.weekday - 1];
    return Center(
      child: Stagger(
        index: 0,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(color: Palette.butter, shape: BoxShape.circle),
                child: const Icon(Icons.weekend_outlined, size: 42, color: Palette.ink),
              ),
              const SizedBox(height: 20),
              Text(
                adminView ? "$weekday is $name's day off" : '$weekday is your day off',
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'DMSerifDisplay', fontSize: 26, height: 1.15),
              ),
              const SizedBox(height: 8),
              Text(
                adminView
                    ? 'No checklist today. You can switch on this day for an event under Schedules.'
                    : 'No checklist today. If there is an event, you will be told in advance.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Palette.muted, fontSize: 15, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Medicine reminders due now, and the offer to switch on phone reminders.
class ReminderBanners extends StatefulWidget {
  const ReminderBanners({super.key, required this.personId});

  final String personId;

  @override
  State<ReminderBanners> createState() => _ReminderBannersState();
}

class _ReminderBannersState extends State<ReminderBanners> {
  String permission = pushPermission();
  bool dismissed = false;

  Future<void> _turnOn(AppState state) async {
    await state.enablePush();
    setState(() => permission = pushPermission());
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final due = state.dueReminders;
    final children = <Widget>[
      for (final r in due) _ReminderCard(reminder: r),
      if (needsHomeScreen() && !dismissed)
        ActionCard(
          icon: Icons.add_to_home_screen,
          title: 'Add this app to your Home Screen',
          body:
              'iPhone only sends reminders to apps on the Home Screen. In Safari tap the Share button, '
              'then "Add to Home Screen". Open the app from there and turn on reminders.',
          actions: [TextButton(onPressed: () => setState(() => dismissed = true), child: const Text('Later'))],
        )
      else if (permission == 'default' && !dismissed)
        ActionCard(
          icon: Icons.notifications_on_outlined,
          title: 'Turn on reminders',
          body: 'Your phone tells you when a task or a medicine is due, and when one is not done yet.',
          actions: [
            TextButton(onPressed: () => setState(() => dismissed = true), child: const Text('Not now')),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
              onPressed: () => _turnOn(state),
              child: const Text('Turn on'),
            ),
          ],
        )
      else if (permission == 'denied' && !dismissed)
        ActionCard(
          icon: Icons.notifications_off_outlined,
          title: 'Reminders are blocked',
          body: 'Allow notifications for this app in the phone settings to get task reminders.',
          actions: [TextButton(onPressed: () => setState(() => dismissed = true), child: const Text('OK'))],
        ),
    ];
    return AnimatedSize(
      alignment: Alignment.topCenter,
      curve: Curves.easeOut,
      duration: const Duration(milliseconds: 280),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.reminder});

  final MedicineReminder reminder;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final task = reminder.task;
    return ActionCard(
      icon: Icons.medication_outlined,
      title: 'Medicine time',
      body:
          '${reminder.dose.label} for ${reminder.parents.map((p) => p.label).join(' and ')}. '
          '${task.title}, ${timeRange(task.start, task.end)}.',
      highlight: true,
      actions: [
        TextButton(onPressed: () => state.snooze(reminder.key), child: const Text('In 10 minutes')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
          onPressed: () => openTaskSheet(context, task, state.today, false),
          child: const Text('Open'),
        ),
      ],
    );
  }
}

class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.actions,
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<Widget> actions;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
    padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
    decoration: BoxDecoration(
      color: Palette.butter,
      border: Border.all(color: highlight ? Palette.ink : Colors.transparent, width: 2),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Palette.ink),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(body, style: const TextStyle(color: Palette.text, fontSize: 14, height: 1.35)),
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(alignment: WrapAlignment.end, spacing: 4, children: actions),
        ),
      ],
    ),
  );
}

/// One task on the checklist.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.day,
    required this.onTap,
    this.coveringFor,
    this.onOpenShopping,
  });

  final Task task;
  final DateTime day;
  final VoidCallback onTap;

  /// Whose task this is, when covering their morning.
  final String? coveringFor;
  final VoidCallback? onOpenShopping;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final taskState = state.stateOf(task, day);
    if (taskState == TaskState.rest) return BreakRow(task: task);
    final tick = state.tickFor(task, day);
    final note = state.noteFor(task, day);
    final missed = taskState == TaskState.missed;
    final now = taskState == TaskState.now;
    final hasExtra = task.extraNote.isNotEmpty && task.extraDays.contains(day.weekday);
    final accent = missed ? Palette.alert : Palette.ink;

    final lines = <Widget>[
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Text(
            timeRange(task.start, task.end),
            style: TextStyle(
              color: missed ? Palette.alert : Palette.muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (now || missed) _Pill(text: now ? 'NOW' : 'MISSED', color: accent),
          if (coveringFor != null) _Pill(text: 'COVERING ${coveringFor!.toUpperCase()}', color: Palette.amber),
        ],
      ),
      const SizedBox(height: 4),
      AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 260),
        style: TextStyle(
          color: missed ? Palette.alert : (taskState == TaskState.done ? Palette.muted : Palette.text),
          fontFamily: 'DMSerifDisplay',
          fontSize: 19,
          fontWeight: FontWeight.w400,
          height: 1.2,
        ),
        child: Text(task.title),
      ),
      if (task.details.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(task.details, style: const TextStyle(color: Palette.muted, fontSize: 14, height: 1.35)),
      ],
      if (hasExtra) ...[const SizedBox(height: 8), ExtraDaysBox(days: task.extraDays, text: task.extraNote)],
      ...[const SizedBox(height: 8), KindStatus(task: task, day: day)],
      if (note != null) ...[const SizedBox(height: 8), NoteView(note)],
      if (tick != null && tick.photos.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (i, photo) in tick.photos.indexed)
              PhotoThumb(photo: photo, size: 56, onOpen: () => openPhotos(context, tick.photos, i)),
          ],
        ),
      ],
      if (task.shopping && onOpenShopping != null) ...[
        const SizedBox(height: 4),
        TextButton.icon(
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 36),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const Icon(Icons.shopping_basket_outlined, size: 18),
          label: const Text('Open shopping list'),
          onPressed: onOpenShopping,
        ),
      ],
      AnimatedSize(
        alignment: Alignment.topLeft,
        curve: Curves.easeOut,
        duration: const Duration(milliseconds: 260),
        child: tick != null && !tick.done
            ? Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Not done: ${tick.reason.isEmpty ? 'no reason given' : tick.reason}',
                  style: const TextStyle(color: Palette.alert, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              )
            : tick != null
            ? Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Done ${clockOf(tick.time)}${minuteOfDay(tick.time) > task.end ? ' (late)' : ''}',
                      style: const TextStyle(color: Palette.ink, fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    if (!tick.sent) const PendingNote(),
                  ],
                ),
              )
            : missed
            ? Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Not ticked by ${clock(task.end)}',
                  style: const TextStyle(color: Palette.alert, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              )
            : const SizedBox(width: double.infinity),
      ),
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: missed ? Palette.alertLight : (now ? Palette.butterLight : Palette.white),
        border: Border.all(
          color: missed ? Palette.alert : (now ? Palette.ink : Colors.transparent),
          width: now ? 2 : 1.5,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: lines),
                ),
                const SizedBox(width: 8),
                TickButton(state: taskState, onPressed: onTap),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
    child: Text(
      text,
      style: const TextStyle(
        color: Palette.white,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    ),
  );
}

/// A break, shown as a quiet line instead of a card.
class BreakRow extends StatelessWidget {
  const BreakRow({super.key, required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(14, 6, 0, 6),
    padding: const EdgeInsets.fromLTRB(28, 4, 24, 4),
    decoration: const BoxDecoration(
      border: Border(left: BorderSide(color: Palette.line, width: 2)),
    ),
    child: Row(
      children: [
        const Icon(Icons.local_cafe_outlined, size: 18, color: Palette.faint),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: task.title,
                  style: const TextStyle(color: Palette.muted, fontWeight: FontWeight.w700),
                ),
                TextSpan(text: '  ${timeRange(task.start, task.end)}'),
                if (task.details.isNotEmpty) TextSpan(text: ' · ${task.details}'),
              ],
            ),
            style: const TextStyle(color: Palette.faint, fontSize: 13.5),
          ),
        ),
      ],
    ),
  );
}

/// "Mon / Wed / Fri: extra steps".
class ExtraDaysBox extends StatelessWidget {
  const ExtraDaysBox({super.key, required this.days, required this.text});

  final Set<int> days;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Palette.cream,
      border: Border.all(color: Palette.sand),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '${slashDays(days)}:  ', style: const TextStyle(fontWeight: FontWeight.w700)),
          TextSpan(text: text),
        ],
      ),
      style: const TextStyle(color: Palette.text, fontSize: 13.5, height: 1.35),
    ),
  );
}

/// Medicine, readings or photo status on a task card.
class KindStatus extends StatelessWidget {
  const KindStatus({super.key, required this.task, required this.day});

  final Task task;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final tick = state.tickFor(task, day);
    const line = TextStyle(color: Palette.text, fontSize: 13, height: 1.4);
    switch (task.kind) {
      case TaskKind.medicine:
        final dose = task.dose;
        if (dose == null) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final parent in Parent.values)
              Builder(
                builder: (context) {
                  final record = state.doseRecord(dose, parent, day);
                  final given = record != null;
                  final text = given
                      ? '${parent.label}: given ${clockOf(record.time)} by ${state.person(record.byId).name}'
                            '${record.sent ? '' : ' (not sent yet)'}'
                      : '${parent.label}: ${dose.label.toLowerCase()} not given yet';
                  return Row(
                    children: [
                      Icon(
                        given ? Icons.check : Icons.medication_outlined,
                        size: 16,
                        color: given ? Palette.ink : Palette.muted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(text, style: line.copyWith(color: given ? Palette.text : Palette.muted)),
                      ),
                    ],
                  );
                },
              ),
          ],
        );
      case TaskKind.vitals:
        if (tick == null || tick.vitals.isEmpty) {
          return const HintChip(icon: Icons.monitor_heart_outlined, text: 'Enter BP, blood sugar and oxygen');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final e in tick.vitals.entries) Text('${e.key.label}: ${e.value.summary()}', style: line),
          ],
        );
      case TaskKind.photo:
        if (tick != null) return const SizedBox.shrink();
        return const HintChip(icon: Icons.photo_camera_outlined, text: 'Photo of common areas only');
      case TaskKind.tick:
        if (tick != null) return const SizedBox.shrink();
        return const HintChip(icon: Icons.photo_camera_outlined, text: 'Photo needed as proof');
      case TaskKind.rest:
        return const SizedBox.shrink();
    }
  }
}

/// The round tick button at the end of a task card.
class TickButton extends StatelessWidget {
  const TickButton({super.key, required this.state, required this.onPressed});

  final TaskState state;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final done = state == TaskState.done;
    final missed = state == TaskState.missed;
    final Widget mark = done
        ? const Icon(Icons.check_rounded, size: 26, color: Palette.white, key: ValueKey('done'))
        : missed
        ? const Text(
            '!',
            key: ValueKey('missed'),
            style: TextStyle(color: Palette.alert, fontSize: 18, fontWeight: FontWeight.w700),
          )
        : const SizedBox(key: ValueKey('open'));
    return Semantics(
      button: true,
      checked: done,
      label: done ? 'Done' : 'Mark done',
      excludeSemantics: true,
      child: InkWell(
        customBorder: const CircleBorder(),
        radius: 30,
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: done ? Palette.ink : Palette.white,
            shape: BoxShape.circle,
            border: Border.all(color: missed ? Palette.alert : Palette.ink, width: 2.5),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 420),
            switchInCurve: Curves.elasticOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
            child: mark,
          ),
        ),
      ),
    );
  }
}


/// Start and end breaks and free time; both are logged for admin.
class TimeLogCard extends StatelessWidget {
  const TimeLogCard({super.key, required this.personId});

  final String personId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final open = state.openLog(personId);
    final today = state.today;
    final rest = state.timeOn(personId, today, TimeKind.rest);
    final free = state.timeOn(personId, today, TimeKind.free);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(color: Palette.white, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            open == null
                ? 'Break ${hoursMinutes(rest)} of 2 h \u00b7 Free time ${hoursMinutes(free)}'
                : 'On ${open.kind.label.toLowerCase()} since ${clockOf(open.start)}',
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          const Text('12-hour duty with a 2-hour break. Log every break and free time.', style: bodyMuted),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: open != null
                ? [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text('End ${open.kind.label.toLowerCase()}'),
                      onPressed: state.endLog,
                    ),
                  ]
                : [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                      icon: const Icon(Icons.local_cafe_outlined),
                      label: const Text('Start break'),
                      onPressed: () => state.startLog(TimeKind.rest),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                      icon: const Icon(Icons.self_improvement_outlined),
                      label: const Text('Start free time'),
                      onPressed: () => state.startLog(TimeKind.free),
                    ),
                  ],
          ),
        ],
      ),
    );
  }
}
