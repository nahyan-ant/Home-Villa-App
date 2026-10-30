import 'models.dart';

/// Ready-made schedules to start a new maid with, from the schedules Dei
/// prepared on 21 October 2026, plus a wake-up punch-in.
const scheduleTemplates = {'mary': "Mary's schedule", 'nisha': "Nisha's schedule"};

typedef _T = (
  int start,
  int end,
  String title,
  String details, {
  TaskKind kind,
  Dose? dose,
  String extraNote,
  Set<int>? extraDays,
  bool shopping,
});

_T _t(
  int start,
  int end,
  String title,
  String details, {
  TaskKind kind = TaskKind.tick,
  Dose? dose,
  String extraNote = '',
  Set<int>? extraDays,
  bool shopping = false,
}) => (
  start,
  end,
  title,
  details,
  kind: kind,
  dose: dose,
  extraNote: extraNote,
  extraDays: extraDays,
  shopping: shopping,
);

final _punchIn = _t(390, 405, 'Wake-up punch-in', 'Take a photo when you start your day.');

final Map<String, List<_T>> _templates = {
  'mary': [
    _punchIn,
    _t(420, 480, "Mother's morning care", 'Wake up, assist mother with washroom, personal hygiene, dressing and breakfast'),
    _t(480, 540, 'Medicines and light physiotherapy', 'Give prescribed 8:00 AM medicines. Assist mother with light physiotherapy, gentle hand and leg movements, with rest intervals', kind: TaskKind.medicine, dose: Dose.morning),
    _t(540, 600, 'Diet, clothing and kitchen check', 'Arrange lunch diet and clothing for both parents, check kitchen arrangements and have breakfast'),
    _t(600, 630, 'Vital checks', 'Check BP, blood sugar and oxygen saturation for both parents according to their monitoring plans', kind: TaskKind.vitals),
    _t(630, 660, 'Fresh air for mother', 'Take mother outside for fresh air and supervised gentle movement'),
    _t(660, 750, 'Villa inspection', 'Inspect both villas, check cleaning, kitchen, bathrooms and household requirements', kind: TaskKind.photo),
    _t(750, 780, 'Lunch arrangement', 'Arrange lunch for both parents and verify dietary requirements'),
    _t(780, 810, 'Lunch', 'Lunch and assist parents with meals as required'),
    _t(810, 870, 'Rest break', '1 hour', kind: TaskKind.rest),
    _t(870, 990, 'Office cleaning', 'Rooms, desks, floors, washrooms, pantry and common areas', kind: TaskKind.photo),
    _t(990, 1005, "Mother's afternoon exercise", 'Light exercise'),
    _t(1005, 1020, "Mother's evening exercise", 'Light exercise and comfortable positioning'),
    _t(1020, 1050, 'Dinner break', '30 minutes', kind: TaskKind.rest),
    _t(1050, 1110, "Parents' evening requirements", 'Check clothes, comfort and care supplies'),
    _t(1110, 1170, "Parents' dinner", 'Supervise dinner arrangements and assist with meals'),
    _t(1170, 1230, 'Evening medicines and supplies', "Check prescribed evening medicines, organize medical supplies and prepare the next day's care requirements", kind: TaskKind.medicine, dose: Dose.evening),
    _t(1230, 1260, 'Closing', "Final parents' care checks, guest assistance when required and household handover"),
  ],
  'nisha': [
    _punchIn,
    _t(420, 450, 'Arrive and prepare breakfast', 'Reach Villa 15 by 7:00 AM sharp'),
    _t(450, 480, 'Breakfast service', 'Serve Mama and Papa; morning medicines with breakfast', kind: TaskKind.medicine, dose: Dose.morning),
    _t(480, 540, 'Kitchen clean-up', 'Wash her own breakfast dishes, wipe counters and stove'),
    _t(540, 600, 'Fridge and kitchen cupboard arrangement', 'Check expiry dates, arrange items, update the inventory / shopping list', shopping: true),
    _t(600, 720, 'Lunch cooking', '2 hours of cooking', extraNote: "Mama is out at physiotherapy with Mary, so also batch-prep staff food and dinner ingredients, and have a drink and light snack ready for Mama's return at 12:00", extraDays: {1, 3, 5}),
    _t(720, 780, 'Clean-up and table setting', 'Wash cooking dishes, set the table'),
    _t(780, 840, 'Lunch', 'Serve lunch at 1:00 PM; afternoon medicines; clear and wash dishes', kind: TaskKind.medicine, dose: Dose.afternoon),
    _t(840, 960, 'Break', 'Rest time', kind: TaskKind.rest),
    _t(960, 1080, 'Evening tea and kitchen upkeep', 'Prepare evening tea / snacks for Mama and Papa; deep-clean kitchen surfaces and stove; finalise list of items to buy', shopping: true),
    _t(1080, 1200, 'Dinner preparation', '2 hours of cooking'),
    _t(1200, 1260, 'Dinner and closing', 'Serve dinner at 8:00 PM; evening medicines; wash all dishes and close the kitchen', kind: TaskKind.medicine, dose: Dose.evening),
  ],
};

/// The tasks of [template] for [ownerId], starting on [from].
List<Task> templateTasks(String template, String ownerId, DateTime from, String Function() newId) => [
  for (final t in _templates[template] ?? const <_T>[])
    Task(
      id: newId(),
      validFrom: from,
      ownerId: ownerId,
      start: t.$1,
      end: t.$2,
      title: t.$3,
      details: t.$4,
      kind: t.kind,
      dose: t.dose,
      extraNote: t.extraNote,
      extraDays: t.extraDays,
      shopping: t.shopping,
      weight: t.$3 == 'Wake-up punch-in' ? 2 : null,
    ),
];
