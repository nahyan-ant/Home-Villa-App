import 'package:flutter/material.dart';

import '../app_state.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/top_actions.dart';
import 'maid_day.dart';
import 'schedules.dart';
import 'shopping_list.dart';
import 'team.dart';

/// Boss, Cielo and Dei: progress, shopping and schedules.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.user});

  final Person user;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int tab = 0;

  /// The day being looked at; null means today.
  DateTime? day;

  void _showDay(AppState state, DateTime chosen) {
    final isToday = chosen == state.today;
    if (!isToday) state.openDay(chosen);
    setState(() => day = isToday ? null : chosen);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final shown = day ?? state.today;
    final isToday = shown == state.today;
    final title = switch (tab) {
      0 => isToday ? 'Today' : weekdayNames[shown.weekday - 1],
      1 => 'Shopping list',
      _ => 'Schedules',
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          Center(child: Text(widget.user.name, style: const TextStyle(color: Palette.muted, fontSize: 14))),
          ...topActions(context),
        ],
      ),
      body: Column(
        children: [
          if (tab < 2) DayPicker(day: shown, onChanged: (d) => _showDay(state, d)),
          Expanded(
            child: Swap(
              swapKey: '$tab ${dayKey(shown)}',
              child: switch (tab) {
                0 => AdminToday(day: shown),
                1 => ShoppingListView(day: shown, keepsList: false),
                _ => const SchedulesPage(),
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.shopping_basket_outlined), label: 'Shopping'),
          NavigationDestination(icon: Icon(Icons.edit_calendar_outlined), label: 'Schedules'),
        ],
      ),
    );
  }
}

/// Step through earlier days, up to 60 days back.
class DayPicker extends StatelessWidget {
  const DayPicker({super.key, required this.day, required this.onChanged});

  final DateTime day;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final today = AppScope.of(context).today;
    final earliest = DateTime(today.year, today.month, today.day - 60);
    final isToday = day == today;
    DateTime shift(int days) => DateTime(day.year, day.month, day.day + days);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Day before',
            onPressed: day.isAfter(earliest) ? () => onChanged(shift(-1)) : null,
          ),
          Expanded(
            child: TextButton.icon(
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(isToday ? 'Today, ${shortDate(day)}' : shortDate(day)),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  firstDate: earliest,
                  lastDate: today,
                  initialDate: day,
                  helpText: 'Show day',
                );
                if (picked != null) onChanged(picked);
              },
            ),
          ),
          if (!isToday) TextButton(onPressed: () => onChanged(today), child: const Text('Today')),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Day after',
            onPressed: isToday ? null : () => onChanged(shift(1)),
          ),
        ],
      ),
    );
  }
}

/// Every maid's day at a glance, with medicine alerts on top.
class AdminToday extends StatelessWidget {
  const AdminToday({super.key, required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final missing = state.missingDoses(day);
    final twice = state.doubleDoses(day);
    final children = <Widget>[];
    var index = 0;
    final waiting = state.waitingToJoin.length;
    if (waiting > 0) {
      children.addAll([
        Stagger(
          index: index++,
          child: Material(
            color: Palette.butter,
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(Icons.person_add_alt_1_outlined, color: Palette.ink),
              title: Text(
                waiting == 1 ? '1 person is waiting to join' : '$waiting people are waiting to join',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('Approve or reject them under Team.'),
              trailing: const Icon(Icons.arrow_forward_rounded),
              onTap: () =>
                  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TeamScreen())),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ]);
    }
    if (twice.isNotEmpty) {
      children.addAll([
        Stagger(
          index: index++,
          child: AlertCard(
            icon: Icons.warning_amber_rounded,
            title: 'Medicine recorded twice',
            lines: [
              for (final d in twice)
                '${d.parent.label}: ${d.dose.label.toLowerCase()}, given by '
                    '${d.records.map((r) => '${state.person(r.byId).name} at ${clockOf(r.time)}').join(' and ')}',
            ],
            footnote:
                'A phone was offline, so neither maid could see the other had given it. '
                'Check with them, and with the doctor if needed.',
          ),
        ),
        const SizedBox(height: 12),
      ]);
    }
    if (missing.isNotEmpty) {
      children.addAll([
        Stagger(
          index: index++,
          child: AlertCard(
            icon: Icons.medication_outlined,
            title: 'Medicines not recorded',
            lines: [
              for (final m in missing)
                '${m.parent.label}: ${m.dose.label.toLowerCase()}, due by ${clock(m.dueBy)}',
            ],
            footnote: 'Check with the maid on duty before anyone gives it, in case it was given but not ticked.',
          ),
        ),
        const SizedBox(height: 16),
      ]);
    }
    for (final maid in state.maidsOn(day)) {
      children.addAll([
        Stagger(index: index++, child: MaidCard(maid: maid, day: day)),
        const SizedBox(height: 12),
      ]);
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 32), children: children);
  }
}

class AlertCard extends StatelessWidget {
  const AlertCard({
    super.key,
    required this.icon,
    required this.title,
    required this.lines,
    required this.footnote,
  });

  final IconData icon;
  final String title;
  final List<String> lines;
  final String footnote;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Palette.alertLight,
      border: Border.all(color: Palette.alert, width: 1.5),
      borderRadius: BorderRadius.circular(28),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Palette.alert),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                style: const TextStyle(color: Palette.alert, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(line, style: const TextStyle(color: Palette.alert, fontSize: 14.5, height: 1.3)),
          ),
        const SizedBox(height: 8),
        Text(footnote, style: const TextStyle(color: Palette.text, fontSize: 13, height: 1.35)),
      ],
    ),
  );
}

/// One maid's progress, review status and current task.
class MaidCard extends StatelessWidget {
  const MaidCard({super.key, required this.maid, required this.day});

  final Person maid;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final off = state.isDayOff(maid.id, day);
    final progress = state.progress(maid.id, day);
    final current = state.currentTask(maid.id, day);
    final review = state.reviewOf(maid.id, day);
    final notes = state.noteCount(maid.id, day);
    final phase = state.phaseOf(maid.id);

    final (String status, bool alert) = off
        ? ('Day off', false)
        : review?.status == ReviewStatus.confirmed
        ? ('Confirmed', false)
        : review?.status == ReviewStatus.sentBack
        ? ('Sent back', true)
        : day.isBefore(state.today)
        ? ('Not reviewed', false)
        : progress.done == progress.total
        ? ('Ready to confirm', false)
        : ('In progress', false);
    final confirmed = status == 'Confirmed';
    final color = personColor(maid.id);
    final flagged = progress.missed > 0 && !off;

    final children = <Widget>[
      Row(
        children: [
          Avatar(
            id: maid.id,
            name: maid.name,
            size: 44,
            style: const TextStyle(color: Palette.white, fontFamily: 'DMSerifDisplay', fontSize: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(maid.name, style: const TextStyle(fontFamily: 'DMSerifDisplay', fontSize: 22)),
                Text(maid.duties, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyMuted),
                if (phase != Phase.none)
                  Text(
                    'Repeated misses: ${phase.label}',
                    style: const TextStyle(color: Palette.alert, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: alert ? Palette.white : (confirmed ? Palette.ink : Palette.butter),
              border: Border.all(color: alert ? Palette.text : Colors.transparent, width: 1.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: confirmed ? Palette.white : Palette.text,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ];
    if (!off) {
      children.addAll([
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                '${progress.done} of ${progress.total} done',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            if (notes > 0) ...[
              const Icon(Icons.sticky_note_2_outlined, size: 16, color: Palette.muted),
              const SizedBox(width: 4),
              Text(
                notes == 1 ? '1 note' : '$notes notes',
                style: const TextStyle(color: Palette.muted, fontSize: 14, fontWeight: FontWeight.w700),
              ),
              if (progress.missed > 0) const SizedBox(width: 12),
            ],
            if (progress.missed > 0)
              Text(
                '${progress.missed} missed',
                style: const TextStyle(color: Palette.alert, fontSize: 14, fontWeight: FontWeight.w700),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ProgressBar(value: progress.total == 0 ? 0 : progress.done / progress.total, color: color),
        const SizedBox(height: 10),
        Text(
          'Score ${(progress.score * 100).round()}%'
          ' \u00b7 Break ${hoursMinutes(state.timeOn(maid.id, day, TimeKind.rest))}'
          ' \u00b7 Free ${hoursMinutes(state.timeOn(maid.id, day, TimeKind.free))}',
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          current == null
              ? 'Hours: ${maid.hours}'
              : 'Now: ${current.title} (${timeRange(current.start, current.end)})',
          style: const TextStyle(color: Palette.muted, fontSize: 13.5),
        ),
      ]);
    }
    return Material(
      color: Palette.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: flagged ? Palette.alert : Colors.transparent,
          width: flagged ? 1.5 : 0,
        ),
      ),
      child: InkWell(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => MaidDayScreen(maid: maid, day: day))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
      ),
    );
  }
}
