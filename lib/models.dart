import 'dart:typed_data';

import 'format.dart';

/// How a task is ticked off. Every kind but [rest] needs a photo as proof.
enum TaskKind {
  tick('Photo proof'),
  medicine('Medicines'),
  vitals('Vital checks'),
  photo('Cleaning photo'),
  rest('Break');

  const TaskKind(this.label);
  final String label;
}

/// The three daily medicine rounds.
enum Dose {
  morning('Morning medicines'),
  afternoon('Afternoon medicines'),
  evening('Evening medicines');

  const Dose(this.label);
  final String label;
}

enum Parent {
  mama('Mama'),
  papa('Papa');

  const Parent(this.label);
  final String label;
}

enum ChangeType {
  added('New task'),
  changed('Changed'),
  removed('Removed');

  const ChangeType(this.label);
  final String label;
}

enum ReviewStatus { confirmed, sentBack }

enum Compensation {
  dayOff('Replacement day off'),
  extraPay('Extra pay');

  const Compensation(this.label);
  final String label;
}

/// Where a task stands on a given day.
enum TaskState { upcoming, now, done, missed, rest }

enum TimeKind {
  rest('break', 'Break'),
  free('free', 'Free time');

  const TimeKind(this.code, this.label);
  final String code;
  final String label;
}

/// Repeated misses move a maid up these steps.
enum Phase {
  none(''),
  warning('Warning'),
  finalWarning('Final warning'),
  action('Action');

  const Phase(this.label);
  final String label;
}

T _byName<T extends Enum>(List<T> values, String? name, T fallback) =>
    values.firstWhere((v) => v.name == name, orElse: () => fallback);

DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String);
DateTime _time(Object? v) => DateTime.parse(v as String).toLocal();

/// A maid or an admin.
class Person {
  Person({
    required this.id,
    required this.name,
    required this.isAdmin,
    this.isPending = false,
    this.duties = '',
    this.hours = '',
    this.phone = '',
    this.email = '',
    this.dayOff,
    required this.since,
    this.removedFrom,
  });

  factory Person.fromRow(Map<String, dynamic> r) => Person(
    id: r['id'] as String,
    name: r['name'] as String,
    isAdmin: r['role'] == 'admin',
    isPending: r['role'] == 'pending',
    duties: r['duties'] as String? ?? '',
    hours: r['hours'] as String? ?? '',
    phone: r['phone'] as String? ?? '',
    email: r['email'] as String? ?? '',
    dayOff: r['day_off'] as int?,
    since: _date(r['since'])!,
    removedFrom: _date(r['removed_from']),
  );

  final String id;
  String name;
  final bool isAdmin;

  /// Signed up but not approved by an admin yet.
  final bool isPending;
  String duties;
  String hours;
  String phone;
  String email;

  /// Weekly day off, 1 = Monday.
  int? dayOff;
  final DateTime since;
  DateTime? removedFrom;
}

/// One version of a task on a maid's schedule.
///
/// Editing a task never rewrites history: it ends the current version the day
/// before the change and adds a new version (same [seriesId]) from that day.
class Task {
  Task({
    required this.id,
    String? seriesId,
    this.validFrom,
    this.validUntil,
    required this.ownerId,
    required this.start,
    required this.end,
    required this.title,
    this.details = '',
    this.kind = TaskKind.tick,
    this.dose,
    Set<int>? days,
    this.extraNote = '',
    Set<int>? extraDays,
    this.shopping = false,
    int? weight,
  }) : seriesId = seriesId ?? id,
       days = days ?? {1, 2, 3, 4, 5, 6, 7},
       extraDays = extraDays ?? {},
       weight = weight ?? defaultWeight(kind);

  factory Task.fromRow(Map<String, dynamic> r) => Task(
    id: r['id'] as String,
    seriesId: r['series_id'] as String,
    validFrom: _date(r['valid_from']),
    validUntil: _date(r['valid_until']),
    ownerId: r['owner_id'] as String,
    start: r['start_min'] as int,
    end: r['end_min'] as int,
    title: r['title'] as String,
    details: r['details'] as String? ?? '',
    kind: _byName(TaskKind.values, r['kind'] as String?, TaskKind.tick),
    dose: r['dose'] == null ? null : _byName(Dose.values, r['dose'] as String, Dose.morning),
    days: {...(r['days'] as List).cast<int>()},
    extraNote: r['extra_note'] as String? ?? '',
    extraDays: {...(r['extra_days'] as List).cast<int>()},
    shopping: r['shopping'] as bool? ?? false,
    weight: r['weight'] as int?,
  );

  /// Medicines count most, then readings; breaks count nothing.
  static int defaultWeight(TaskKind kind) => switch (kind) {
    TaskKind.medicine => 3,
    TaskKind.vitals => 2,
    TaskKind.rest => 0,
    _ => 1,
  };

  String id;
  final String seriesId;
  DateTime? validFrom;
  DateTime? validUntil;
  String ownerId;

  /// Minutes after midnight.
  int start;
  int end;
  String title;
  String details;
  TaskKind kind;
  Dose? dose;

  /// Weekdays, 1 = Monday.
  final Set<int> days;

  /// Extra steps on [extraDays] only.
  String extraNote;
  final Set<int> extraDays;

  /// Shows an "Open shopping list" button on the card.
  final bool shopping;

  /// Share of the day's score.
  int weight;

  Map<String, dynamic> toRow() => {
    'id': id,
    'series_id': seriesId,
    'owner_id': ownerId,
    'valid_from': validFrom == null ? null : dayKey(validFrom!),
    'valid_until': validUntil == null ? null : dayKey(validUntil!),
    'start_min': start,
    'end_min': end,
    'title': title,
    'details': details,
    'kind': kind.name,
    'dose': dose?.name,
    'days': days.toList()..sort(),
    'extra_note': extraNote,
    'extra_days': extraDays.toList()..sort(),
    'shopping': shopping,
    'weight': weight,
  };

  Task copy() => Task(
    id: id,
    seriesId: seriesId,
    validFrom: validFrom,
    validUntil: validUntil,
    ownerId: ownerId,
    start: start,
    end: end,
    title: title,
    details: details,
    kind: kind,
    dose: dose,
    days: Set.of(days),
    extraNote: extraNote,
    extraDays: Set.of(extraDays),
    shopping: shopping,
    weight: weight,
  );
}

class Vitals {
  Vitals(this.sys, this.dia, this.sugar, this.oxygen);

  factory Vitals.fromJson(Map<String, dynamic> j) =>
      Vitals(j['sys'] as num?, j['dia'] as num?, j['sugar'] as num?, j['oxygen'] as num?);

  final num? sys;
  final num? dia;
  final num? sugar;
  final num? oxygen;

  Map<String, dynamic> toJson() => {'sys': sys, 'dia': dia, 'sugar': sugar, 'oxygen': oxygen};

  String summary() {
    final parts = <String>[];
    if (sys != null || dia != null) {
      parts.add('BP ${sys ?? '–'}/${dia ?? '–'}');
    }
    if (sugar != null) parts.add('Sugar $sugar mg/dL');
    if (oxygen != null) parts.add('Oxygen $oxygen%');
    return parts.join(' · ');
  }
}

/// A proof photo: in storage once sent, or still on this phone.
class Photo {
  Photo({required this.path, required this.label, this.bytes});

  factory Photo.fromJson(Map<String, dynamic> j) =>
      Photo(path: j['path'] as String, label: j['label'] as String? ?? '');

  /// Where it lives in the "proof" bucket.
  final String path;
  final String label;

  /// Set while the photo is on this phone.
  final Uint8List? bytes;

  Map<String, dynamic> toJson() => {'path': path, 'label': label};
}

class Tick {
  Tick({
    required this.day,
    required this.seriesId,
    required this.personId,
    required this.byId,
    required this.time,
    this.done = true,
    this.reason = '',
    Map<Parent, Vitals>? vitals,
    List<Photo>? photos,
    this.sent = true,
  }) : vitals = vitals ?? {},
       photos = photos ?? [];

  factory Tick.fromRow(Map<String, dynamic> r) => Tick(
    day: _date(r['day'])!,
    seriesId: r['series_id'] as String,
    personId: r['person_id'] as String,
    byId: r['by_id'] as String,
    time: _time(r['at']),
    done: r['status'] != 'not_done',
    reason: r['reason'] as String? ?? '',
    vitals: {
      for (final e in (r['vitals'] as Map).entries)
        _byName(Parent.values, e.key as String, Parent.mama): Vitals.fromJson(
          (e.value as Map).cast<String, dynamic>(),
        ),
    },
    photos: [for (final p in r['photos'] as List) Photo.fromJson((p as Map).cast<String, dynamic>())],
  );

  final DateTime day;
  final String seriesId;

  /// Whose task it is; [byId] may differ when someone covers.
  final String personId;
  final String byId;
  final DateTime time;

  /// False when the maid logged that she could not do it, with a [reason].
  final bool done;
  final String reason;
  final Map<Parent, Vitals> vitals;
  final List<Photo> photos;

  /// False while it waits on the phone for the internet.
  bool sent;

  Map<String, dynamic> toRow() => {
    'day': dayKey(day),
    'series_id': seriesId,
    'person_id': personId,
    'by_id': byId,
    'at': time.toUtc().toIso8601String(),
    'status': done ? 'done' : 'not_done',
    'reason': reason,
    'vitals': {for (final e in vitals.entries) e.key.name: e.value.toJson()},
    'photos': [for (final p in photos) p.toJson()],
  };
}

class DoseRecord {
  DoseRecord({
    required this.id,
    required this.day,
    required this.dose,
    required this.parent,
    required this.byId,
    required this.time,
    this.photo,
    this.sent = true,
  });

  factory DoseRecord.fromRow(Map<String, dynamic> r) => DoseRecord(
    id: r['id'] as String,
    day: _date(r['day'])!,
    dose: _byName(Dose.values, r['dose'] as String?, Dose.morning),
    parent: _byName(Parent.values, r['parent'] as String?, Parent.mama),
    byId: r['by_id'] as String,
    time: _time(r['at']),
    photo: r['photo'] == null ? null : Photo.fromJson((r['photo'] as Map).cast<String, dynamic>()),
  );

  final String id;
  final DateTime day;
  final Dose dose;
  final Parent parent;
  final String byId;
  final DateTime time;
  final Photo? photo;
  bool sent;

  Map<String, dynamic> toRow() => {
    'id': id,
    'day': dayKey(day),
    'dose': dose.name,
    'parent': parent.name,
    'by_id': byId,
    'at': time.toUtc().toIso8601String(),
    'photo': photo?.toJson(),
  };
}

class TaskNote {
  TaskNote(this.text, this.byId, this.time, this.sent);

  final String text;
  final String byId;
  final DateTime time;
  bool sent;
}

class MedicineReminder {
  MedicineReminder(this.task, this.dose, this.parents, this.key);

  final Task task;
  final Dose dose;
  final List<Parent> parents;
  final String key;
}

class UpcomingChange {
  UpcomingChange(this.date, this.task, this.type);

  final DateTime date;
  final Task task;
  final ChangeType type;
}

class Review {
  Review(this.status, this.byId, this.time, this.note);

  final ReviewStatus status;
  final String byId;
  final DateTime time;
  final String note;
}

/// A maid working on her weekly day off.
class DayOffWork {
  DayOffWork(this.compensation, this.note);

  final Compensation compensation;
  final String note;
}

class ShopItem {
  ShopItem(this.id, this.name, this.qty, this.bought, this.sent);

  final String id;
  final String name;
  final String qty;
  bool bought;
  bool sent;
}

class ShoppingList {
  final List<ShopItem> items = [];

  /// When Nisha handed it over, as her phone knows it.
  DateTime? handedOver;

  /// When Nisha handed it over, as admin sees it.
  DateTime? handedOverSent;
}

/// A break or free time, started and ended by the maid.
class TimeLog {
  TimeLog({
    required this.id,
    required this.personId,
    required this.day,
    required this.kind,
    required this.start,
    this.end,
    this.sent = true,
  });

  factory TimeLog.fromRow(Map<String, dynamic> r) => TimeLog(
    id: r['id'] as String,
    personId: r['person_id'] as String,
    day: _date(r['day'])!,
    kind: r['kind'] == 'free' ? TimeKind.free : TimeKind.rest,
    start: _time(r['started_at']),
    end: r['ended_at'] == null ? null : _time(r['ended_at']),
  );

  final String id;
  final String personId;
  final DateTime day;
  final TimeKind kind;
  final DateTime start;
  DateTime? end;
  bool sent;

  Duration lengthUntil(DateTime now) => (end ?? now).difference(start);

  Map<String, dynamic> toRow() => {
    'id': id,
    'person_id': personId,
    'day': dayKey(day),
    'kind': kind.code,
    'started_at': start.toUtc().toIso8601String(),
    'ended_at': end?.toUtc().toIso8601String(),
  };
}

/// After a night emergency, [coveringId] does [restingId]'s tasks that start
/// before [untilMin] on [day].
class NightCover {
  NightCover({
    required this.day,
    required this.restingId,
    required this.coveringId,
    this.untilMin = 720,
    this.note = '',
    required this.loggedBy,
  });

  factory NightCover.fromRow(Map<String, dynamic> r) => NightCover(
    day: _date(r['day'])!,
    restingId: r['resting_id'] as String,
    coveringId: r['covering_id'] as String,
    untilMin: r['until_min'] as int,
    note: r['note'] as String? ?? '',
    loggedBy: r['logged_by'] as String? ?? '',
  );

  final DateTime day;
  final String restingId;
  final String coveringId;
  final int untilMin;
  final String note;
  final String loggedBy;

  Map<String, dynamic> toRow() => {
    'day': dayKey(day),
    'resting_id': restingId,
    'covering_id': coveringId,
    'until_min': untilMin,
    'note': note,
    'logged_by': loggedBy,
  };
}

class Contact {
  Contact({required this.id, required this.label, required this.phone, this.sort = 0});

  factory Contact.fromRow(Map<String, dynamic> r) => Contact(
    id: r['id'] as String,
    label: r['label'] as String,
    phone: r['phone'] as String,
    sort: r['sort'] as int? ?? 0,
  );

  final String id;
  String label;
  String phone;
  int sort;

  Map<String, dynamic> toRow() => {'id': id, 'label': label, 'phone': phone, 'sort': sort};
}

class MissingDose {
  MissingDose(this.dueBy, this.dose, this.parent);

  final int dueBy;
  final Dose dose;
  final Parent parent;
}

class DoubleDose {
  DoubleDose(this.dose, this.parent, this.records);

  final Dose dose;
  final Parent parent;
  final List<DoseRecord> records;
}

class Progress {
  Progress(this.done, this.missed, this.total, this.weightDone, this.weightLost, this.weightTotal);

  final int done;
  final int missed;
  final int total;
  final int weightDone;

  /// Weight of missed tasks, deducted from the day.
  final int weightLost;
  final int weightTotal;

  /// The day's score so far: everything not lost yet still counts.
  double get score => weightTotal == 0 ? 1 : (weightTotal - weightLost) / weightTotal;
}
