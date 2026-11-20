import 'models.dart';

/// Ready-made schedules to start a maid with, from the schedules Dei
/// prepared, plus a wake-up punch-in.
const scheduleTemplates = {
  'cecilia': "Cecilia's schedule (19 Nov)",
  'nisha': "Nisha's schedule (13 Nov)",
  'mary': "Mary's schedule (21 Oct)",
};

/// The weekly day off that comes with a template (1 = Monday).
const templateDayOff = {'cecilia': 6, 'nisha': 7};

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
  Set<int>? days,
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
  Set<int>? days,
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
  days: days,
);

final _punchIn = _t(390, 405, 'Wake-up punch-in', 'Take a photo when you start your day.');

// Cecilia's working days: therapy days, the other days, and both (not Saturday).
const _therapy = {1, 3, 5};
const _other = {2, 4, 7};
const _sixDays = {1, 2, 3, 4, 5, 7};

final Map<String, List<_T>> _templates = {
  'cecilia': [
    _t(390, 405, 'Wake-up punch-in', 'Take a photo when you start your day.', days: _sixDays),
    _t(420, 450, "Mama's morning care", 'Villa 15. Washroom, personal hygiene and dressing', days: _sixDays),
    _t(450, 510, 'Breakfast help', 'Villa 9. Assist in the kitchen with breakfast and clear up', days: _sixDays),
    // Therapy days: Monday, Wednesday, Friday.
    _t(510, 570, 'Cleaning (short)', 'Villa 9. Vacuum main rooms; bathrooms; change garbage bags', kind: TaskKind.photo, days: _therapy),
    _t(570, 600, 'Get Mama ready', 'Villa 15. Prepare Mama and leave for the clinic', days: _therapy),
    _t(600, 720, "Mama's physiotherapy", 'Clinic. Accompany and assist Mama', days: _therapy),
    _t(720, 750, 'Bring Mama home', 'Villa 15. Settle Mama after therapy', days: _therapy),
    _t(750, 810, 'Lunch break', '1 hour', kind: TaskKind.rest, days: _therapy),
    // Other days: Tuesday, Thursday, Sunday.
    _t(510, 630, 'Full house cleaning', 'Villa 9. Vacuum all rooms; 2 bathrooms daily and the 3rd on alternate days; change garbage bags', kind: TaskKind.photo, days: _other),
    _t(630, 720, 'Ironing, laundry and arranging', "Villa 9. Ironing; washing machine; arrange Dei's shelf; put things in order", days: _other),
    _t(720, 780, 'Lunch break', '1 hour', kind: TaskKind.rest, days: _other),
    _t(780, 810, 'Finishing', 'Villa 9. Outside toilet and room if required', days: _other),
    // Every working day.
    _t(810, 840, 'Travel to office', 'Going', kind: TaskKind.rest, days: _sixDays),
    _t(840, 960, 'Office cleaning', 'Office. Rooms, desks, floors, washrooms, pantry and common areas', kind: TaskKind.photo, days: _sixDays),
    _t(960, 990, 'Travel back', 'Coming', kind: TaskKind.rest, days: _sixDays),
    _t(990, 1050, 'Villa 15 cleaning', "Villa 15. 2 washrooms, kitchen, laundry room, Mama's room, common area; garbage", kind: TaskKind.photo, extraNote: 'Also clean the guest room (locked on other days).', extraDays: {7}, days: _sixDays),
    _t(1050, 1110, 'Caregiving and laundry', "Villa 15. Mama and Papa's comfort and needs; washing machine and folding", days: _sixDays),
    _t(1110, 1170, 'Evening break', '1 hour', kind: TaskKind.rest, days: _sixDays),
    _t(1170, 1230, 'Dinner help', 'Villa 15. Assist Mama and Papa at dinner', days: _sixDays),
    _t(1230, 1260, 'Evening routine and closing', "Villa 15. Mama's washroom and bedtime; final tidy-up", days: _sixDays),
  ],
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
    _t(480, 540, 'Kitchen clean-up', 'Wash breakfast dishes, wipe counters and stove'),
    _t(540, 600, 'Fridge and kitchen cupboard arrangement', 'Check expiry dates, arrange items, update the inventory / shopping list', shopping: true),
    _t(600, 720, 'Lunch cooking', '2 hours of cooking', extraNote: "While Mama is out at physiotherapy, also batch-prep staff food and dinner ingredients, and have a drink and light snack ready for Mama's return at 12:00", extraDays: {1, 3, 5}),
    _t(720, 780, 'Clean-up and table setting', 'Wash cooking dishes, set the table'),
    _t(780, 840, 'Lunch', 'Serve lunch at 1:00 PM; afternoon medicines; clear and wash dishes', kind: TaskKind.medicine, dose: Dose.afternoon),
    _t(840, 960, 'Break', '2 hours', kind: TaskKind.rest),
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
      extraDays: t.extraDays == null ? null : Set.of(t.extraDays!),
      shopping: t.shopping,
      days: t.days == null ? null : Set.of(t.days!),
      weight: t.$3 == 'Wake-up punch-in' ? 2 : null,
    ),
];
