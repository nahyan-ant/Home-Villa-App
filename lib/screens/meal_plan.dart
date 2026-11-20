import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../format.dart';
import '../hindi.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'task_sheet.dart';

/// The maid's meal plan for today: each dish with its picture; she ticks
/// each one with a photo when it is made.
class MaidMealPlan extends StatelessWidget {
  const MaidMealPlan({super.key, required this.personId});

  final String personId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final day = state.today;
    final items = state.mealsFor(personId, day.weekday);
    final made = items.where((m) => state.mealTickFor(m, day) != null).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      children: [
        Text(longDate(day).toUpperCase(), style: sectionLabel),
        const SizedBox(height: 6),
        Text(
          items.isEmpty ? tr('No meal plan today') : bi('$made of ${items.length} made', '${items.length} में से $made बने'),
          style: const TextStyle(fontFamily: 'DMSerifDisplay', fontSize: 26, height: 1.15),
        ),
        const SizedBox(height: 4),
        Text(
          tr('Follow the pictures. Take a photo of each dish when it is ready.'),
          style: const TextStyle(color: Palette.muted, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 8),
        ..._sections(context, items, day, admin: false),
      ],
    );
  }
}

/// Admin: set each weekday's meal plan for a maid, and see what was made.
class AdminMealPlan extends StatefulWidget {
  const AdminMealPlan({super.key});

  @override
  State<AdminMealPlan> createState() => _AdminMealPlanState();
}

class _AdminMealPlanState extends State<AdminMealPlan> {
  String? personId;
  int? weekday;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final maids = state.maidsOn(state.today);
    if (maids.isEmpty) {
      return const Center(child: Text('No maids on the team yet.', style: bodyMuted));
    }
    // Start with a maid who already has a plan (Nisha), else the first one.
    personId ??= (maids.where((m) => state.hasMealPlan(m.id)).firstOrNull ?? maids.first).id;
    if (!maids.any((m) => m.id == personId)) personId = maids.first.id;
    final wd = weekday ?? state.today.weekday;
    // The most recent date on this weekday, to show what was made.
    final today = state.today;
    final shown = DateTime(today.year, today.month, today.day - ((today.weekday - wd) % 7));
    final items = state.mealsFor(personId!, wd);
    final made = items.where((m) => state.mealTickFor(m, shown) != null).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: [
        DropdownButtonFormField<String>(
          initialValue: personId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Meal plan for'),
          items: [for (final m in maids) DropdownMenuItem(value: m.id, child: Text(m.name))],
          onChanged: (id) => setState(() => personId = id),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var d = 1; d <= 7; d++)
              ChoiceChip(
                label: Text(weekdayNames[d - 1].substring(0, 3)),
                selected: d == wd,
                onSelected: (_) => setState(() => weekday = d),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text('EVERY ${weekdayNames[wd - 1].toUpperCase()}', style: sectionLabel),
        const SizedBox(height: 4),
        Text(
          items.isEmpty
              ? 'No dishes yet'
              : '$made of ${items.length} made${shown == today ? ' today' : ' on ${shortDate(shown)}'}',
          style: const TextStyle(fontFamily: 'DMSerifDisplay', fontSize: 26, height: 1.15),
        ),
        const SizedBox(height: 4),
        const Text(
          'Add each dish with a picture under its part of the day. It repeats every week on this day.',
          style: TextStyle(color: Palette.muted, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.copy_all_outlined, size: 18),
            label: const Text('Copy this day to…'),
            onPressed: items.isEmpty ? null : () => _copy(context, state, personId!, wd),
          ),
        ),
        ..._sections(context, items, shown, admin: true, personId: personId, weekday: wd),
      ],
    );
  }

  Future<void> _copy(BuildContext context, AppState state, String personId, int from) async {
    final to = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text("Copy ${weekdayNames[from - 1]}'s dishes to"),
        children: [
          for (var d = 1; d <= 7; d++)
            if (d != from)
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(d),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    '${weekdayNames[d - 1]}'
                    '${state.mealsFor(personId, d).isEmpty ? '' : ' (replaces ${state.mealsFor(personId, d).length} dishes)'}',
                  ),
                ),
              ),
        ],
      ),
    );
    if (to != null) await state.copyMealDay(personId, from, to);
  }
}

/// The dishes grouped under Morning, Tea, Salads, Main dishes and Fruits.
List<Widget> _sections(
  BuildContext context,
  List<MealItem> items,
  DateTime day, {
  required bool admin,
  String? personId,
  int? weekday,
}) => [
  for (final section in MealSection.values)
    if (admin || items.any((m) => m.section == section)) ...[
      const SizedBox(height: 18),
      Row(
        children: [
          Expanded(
            child: Text(
              (Lang.on && !admin ? '${section.label} · ${section.hindi}' : section.label).toUpperCase(),
              style: sectionLabel,
            ),
          ),
          if (admin)
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add dish'),
              onPressed: () => openMealEditor(context, personId: personId!, weekday: weekday!, section: section),
            ),
        ],
      ),
      const SizedBox(height: 6),
      for (final item in items.where((m) => m.section == section))
        Stagger(
          key: ValueKey(item.id),
          index: 0,
          child: _MealCard(item: item, day: day, admin: admin),
        ),
      if (admin && !items.any((m) => m.section == section))
        const Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Text('Nothing here yet.', style: bodyMuted),
        ),
    ],
];

class _MealCard extends StatefulWidget {
  const _MealCard({required this.item, required this.day, required this.admin});

  final MealItem item;
  final DateTime day;
  final bool admin;

  @override
  State<_MealCard> createState() => _MealCardState();
}

class _MealCardState extends State<_MealCard> {
  bool _busy = false;

  Future<void> _tick(AppState state) async {
    final bytes = await takePhoto();
    if (bytes == null || !mounted) return;
    setState(() => _busy = true);
    await state.tickMeal(widget.item, widget.day, [bytes]);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _undo(AppState state) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr1('Undo?')),
        content: Text(tr('This dish will show as not made again.')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(tr1('Cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(tr1('Undo')),
          ),
        ],
      ),
    );
    if (sure == true) state.undoMealTick(widget.item, widget.day);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final item = widget.item;
    final tick = state.mealTickFor(item, widget.day);
    final done = tick != null;
    final photo = item.photo;
    final canTick = !widget.admin && widget.day == state.today;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Palette.white,
        border: Border.all(color: done ? Palette.ink : Colors.transparent, width: 1.5),
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (photo != null)
            GestureDetector(
              onTap: () => openPhotos(context, [photo], 0),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: ProofImage(
                  photo: photo,
                  fit: BoxFit.cover,
                  placeholder: const ColoredBox(
                    color: Palette.track,
                    child: Center(child: Icon(Icons.restaurant_outlined, color: Palette.faint, size: 32)),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontFamily: 'DMSerifDisplay',
                          fontSize: 19,
                          height: 1.2,
                          color: done ? Palette.muted : Palette.text,
                        ),
                      ),
                      if (item.note.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(item.note, style: const TextStyle(color: Palette.muted, fontSize: 14, height: 1.35)),
                      ],
                      if (tick != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          bi1(
                            'Made ${clockOf(tick.time)} by ${tick.byId == state.user?.id ? 'you' : state.person(tick.byId).name}',
                            '${clockOf(tick.time)} बजे बना',
                          ),
                          style: const TextStyle(color: Palette.ink, fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        if (tick.photos.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            children: [
                              for (final (i, p) in tick.photos.indexed)
                                PhotoThumb(photo: p, size: 56, onOpen: () => openPhotos(context, tick.photos, i)),
                            ],
                          ),
                        ],
                        if (!tick.sent) const PendingNote(),
                      ] else if (canTick) ...[
                        const SizedBox(height: 6),
                        HintChip(icon: Icons.photo_camera_outlined, text: tr1('Photo when ready')),
                      ] else if (widget.admin && !item.sent)
                        const PendingNote(),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (widget.admin)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit ${item.name}',
                    onPressed: () => openMealEditor(
                      context,
                      personId: item.personId,
                      weekday: item.weekday,
                      section: item.section,
                      existing: item,
                    ),
                  )
                else if (canTick)
                  _busy
                      ? const SizedBox(width: 48, height: 48, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2.5)))
                      : _MadeButton(
                          done: done,
                          onPressed: done
                              ? (state.canUndoMeal(item, widget.day) ? () => _undo(state) : null)
                              : () => _tick(state),
                        ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MadeButton extends StatelessWidget {
  const _MadeButton({required this.done, required this.onPressed});

  final bool done;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    checked: done,
    label: done ? 'Made' : 'Take photo and mark made',
    excludeSemantics: true,
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: done ? Palette.ink : Palette.white,
          shape: BoxShape.circle,
          border: Border.all(color: Palette.ink, width: 2.5),
        ),
        child: Icon(
          done ? Icons.check_rounded : Icons.photo_camera_outlined,
          size: done ? 26 : 22,
          color: done ? Palette.white : Palette.ink,
        ),
      ),
    ),
  );
}

/// Add or change a dish on a weekday's plan.
Future<void> openMealEditor(
  BuildContext context, {
  required String personId,
  required int weekday,
  required MealSection section,
  MealItem? existing,
}) => showDialog<void>(
  context: context,
  builder: (_) => _MealEditor(personId: personId, weekday: weekday, section: section, existing: existing),
);

class _MealEditor extends StatefulWidget {
  const _MealEditor({required this.personId, required this.weekday, required this.section, this.existing});

  final String personId;
  final int weekday;
  final MealSection section;
  final MealItem? existing;

  @override
  State<_MealEditor> createState() => _MealEditorState();
}

class _MealEditorState extends State<_MealEditor> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late MealSection section = widget.section;
  Uint8List? newPhoto;
  bool removePhoto = false;

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 80);
    final bytes = await picked?.readAsBytes();
    if (bytes != null && mounted) {
      setState(() {
        newPhoto = bytes;
        removePhoto = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final existing = widget.existing;
    final oldPhoto = removePhoto ? null : existing?.photo;
    final Widget? preview = newPhoto != null
        ? Image.memory(newPhoto!, fit: BoxFit.cover)
        : oldPhoto != null
        ? ProofImage(photo: oldPhoto, fit: BoxFit.cover, placeholder: const ColoredBox(color: Palette.track))
        : null;
    return AlertDialog(
      title: Text(existing == null ? 'Add dish · ${weekdayNames[widget.weekday - 1]}' : 'Edit dish'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<MealSection>(
              initialValue: section,
              decoration: const InputDecoration(labelText: 'Part of the day'),
              items: [for (final s in MealSection.values) DropdownMenuItem(value: s, child: Text(s.label))],
              onChanged: (s) => setState(() => section = s ?? section),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Dish', hintText: 'For example: Vegetable soup'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Note (optional)', hintText: 'For example: Less salt for Papa'),
            ),
            const SizedBox(height: 14),
            if (preview != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(aspectRatio: 16 / 10, child: preview),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(foregroundColor: Palette.alert),
                  onPressed: () => setState(() {
                    newPhoto = null;
                    removePhoto = true;
                  }),
                  child: const Text('Remove picture'),
                ),
              ),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(preview == null ? 'Choose picture' : 'Change picture'),
                  onPressed: () => _pick(ImageSource.gallery),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Camera'),
                  onPressed: () => _pick(ImageSource.camera),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        if (existing != null)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Palette.alert),
            onPressed: () {
              state.removeMealItem(existing);
              Navigator.of(context).pop();
            },
            child: const Text('Remove'),
          ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: _name.text.trim().isEmpty
              ? null
              : () {
                  state.saveMealItem(
                    existing: existing,
                    personId: widget.personId,
                    weekday: widget.weekday,
                    section: section,
                    name: _name.text.trim(),
                    note: _note.text.trim(),
                    newPhoto: newPhoto,
                    removePhoto: removePhoto,
                  );
                  Navigator.of(context).pop();
                },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
