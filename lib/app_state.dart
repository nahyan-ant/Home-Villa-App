import 'dart:async';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'format.dart';
import 'models.dart';
import 'outbox.dart';
import 'push/push.dart';
import 'templates.dart';

/// Everything the app knows, shared by every screen.
///
/// What is on screen is the latest copy from Supabase with this phone's
/// unsent changes laid on top. Every change is saved on the phone first and
/// sent when the internet allows.
class AppState extends ChangeNotifier {
  AppState(this.outbox) {
    _auth = db.auth.onAuthStateChange.listen((change) {
      // Opened from a reset-password email: ask for the new password first.
      if (change.event == AuthChangeEvent.passwordRecovery) recovering = true;
      _onSession(change.session);
    });
    _onSession(db.auth.currentSession);
    _connectivity = Connectivity().onConnectivityChanged.listen((results) {
      if (results.every((r) => r == ConnectivityResult.none)) {
        _setOnline(false);
      } else {
        sync();
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      notifyListeners();
      if (outbox.length > 0 || !online) sync();
    });
  }

  final Outbox outbox;
  SupabaseClient get db => Supabase.instance.client;

  late final StreamSubscription<AuthState> _auth;
  late final StreamSubscription<List<ConnectivityResult>> _connectivity;
  late final Timer _timer;
  RealtimeChannel? _channel;
  Timer? _reloadSoon;

  /// Short messages for the snack bar.
  final _messages = StreamController<String>.broadcast();
  Stream<String> get messages => _messages.stream;

  /// Signed in, but the profile has not loaded yet.
  bool loading = false;
  Session? session;

  /// Who is signed in.
  Person? user;
  bool online = true;

  final List<Person> people = [];
  final List<Task> tasks = [];

  /// Who gives each dose; null means whoever is on duty.
  final Map<Dose, String?> doseOwner = {for (final d in Dose.values) d: null};

  /// Day → person → working on her day off.
  final Map<String, Map<String, DayOffWork>> dayOffWork = {};

  /// Day → resting person → who covers her morning.
  final Map<String, Map<String, NightCover>> covers = {};

  /// Day → task series → tick.
  final Map<String, Map<String, Tick>> ticks = {};

  /// Day → "dose/parent" → records.
  final Map<String, Map<String, List<DoseRecord>>> doses = {};

  /// Day → task series → note.
  final Map<String, Map<String, TaskNote>> notes = {};

  /// Day → person → review.
  final Map<String, Map<String, Review>> reviews = {};

  /// Day → shopping list.
  final Map<String, ShoppingList> shopping = {};

  final Map<String, TimeLog> timeLogs = {};
  final List<Contact> contacts = [];
  final Map<String, String> settings = {};

  /// Reminder key → time it was snoozed until.
  final Map<String, DateTime> snoozed = {};

  /// Earliest day loaded.
  late DateTime _from = today.subtract(const Duration(days: Config.historyDays));

  DateTime get now => DateTime.now();
  DateTime get today => dateOnly(now);
  int get nowMinute => minuteOfDay(now);

  @override
  void dispose() {
    _auth.cancel();
    _connectivity.cancel();
    _timer.cancel();
    _reloadSoon?.cancel();
    _channel?.unsubscribe();
    _messages.close();
    super.dispose();
  }

  void _say(String text) => _messages.add(text);

  void _setOnline(bool value) {
    if (online == value) return;
    online = value;
    notifyListeners();
  }

  // ------------------------------------------------------------- sign in

  Future<String?> signIn(String email, String password) async {
    try {
      await db.auth.signInWithPassword(email: email.trim(), password: password);
      return null;
    } on AuthException catch (e) {
      return e.message == 'Invalid login credentials' ? 'Wrong email or password.' : e.message;
    } catch (_) {
      return 'No internet. Connect and try again.';
    }
  }

  /// Creates an account that waits for an admin to approve it. Returns an
  /// error, or null; [needsEmailCheck] is set when Supabase sent a
  /// confirmation email first.
  Future<String?> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      final res = await db.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'name': name.trim(), 'phone': phone.trim()},
      );
      needsEmailCheck = res.session == null;
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'No internet. Connect and try again.';
    }
  }

  bool needsEmailCheck = false;

  /// Signed in from a reset-password email; a new password is needed.
  bool recovering = false;

  /// Emails a link to set a new password. Returns an error, or null.
  Future<String?> sendPasswordReset(String email) async {
    try {
      await db.auth.resetPasswordForEmail(email.trim(), redirectTo: Uri.base.origin);
      return null;
    } on AuthException catch (e) {
      return e.statusCode == '429' ? 'Too many emails just now. Try again in an hour.' : e.message;
    } catch (_) {
      return 'No internet. Connect and try again.';
    }
  }

  Future<String?> setNewPassword(String password) async {
    try {
      await db.auth.updateUser(UserAttributes(password: password));
      recovering = false;
      notifyListeners();
      _say('Password changed.');
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'No internet. Connect and try again.';
    }
  }

  /// People who signed up and wait for an admin.
  List<Person> get waitingToJoin => people.where((p) => p.isPending).toList();

  /// Lets a person in as maid or admin, optionally with a starting schedule.
  Future<void> approve(Person p, {required bool asAdmin, String? template, String? copyFrom}) async {
    final newTasks = template != null
        ? templateTasks(template, p.id, today, newUuid)
        : [
            if (copyFrom != null)
              for (final t in tasksFor(copyFrom))
                t.copy()
                  ..id = newUuid()
                  ..ownerId = p.id
                  ..validFrom = today
                  ..validUntil = null,
          ];
    await _save([
      Op.update('profiles', {'id': p.id}, {'role': asAdmin ? 'admin' : 'maid', 'since': dayKey(today)}),
      for (final t in newTasks) Op.upsert('tasks', (t.toRow()..['series_id'] = t.id)),
    ]);
  }

  Future<String?> reject(Person p) => _manage({'action': 'reject', 'id': p.id});

  Future<void> signOut() async {
    await outbox.clear();
    await db.auth.signOut();
  }

  Future<void> _onSession(Session? s) async {
    session = s;
    if (s == null) {
      user = null;
      _channel?.unsubscribe();
      _channel = null;
      _clear();
      notifyListeners();
      return;
    }
    loading = user == null;
    notifyListeners();
    await reload();
    loading = false;
    notifyListeners();
    _channel ??= db
        .channel('changes')
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', callback: (_) => _scheduleReload())
        .subscribe();
    await registerPushIfAllowed();
  }

  void _scheduleReload() {
    _reloadSoon?.cancel();
    _reloadSoon = Timer(const Duration(milliseconds: 800), reload);
  }

  // ---------------------------------------------------------------- sync

  bool _syncing = false;

  /// Sends saved changes, then fetches the latest.
  Future<void> sync() async {
    if (_syncing || session == null) return;
    _syncing = true;
    final waiting = outbox.length;
    final ok = await outbox.flush(db, (why) => _say('Could not save a change: $why'));
    _syncing = false;
    _setOnline(ok);
    if (ok && waiting > 0) {
      _say(waiting == 1 ? 'Back online: 1 saved change sent' : 'Back online: $waiting saved changes sent');
    }
    if (ok) await reload();
  }

  Future<List<Map<String, dynamic>>> _fetch(String table, {bool byDay = false}) async {
    final rows = <Map<String, dynamic>>[];
    for (var page = 0; ; page++) {
      var query = db.from(table).select();
      if (byDay) query = query.gte('day', dayKey(_from));
      final batch = await query.range(page * 1000, page * 1000 + 999);
      rows.addAll(batch);
      if (batch.length < 1000) return rows;
    }
  }

  static const _sharedTables = ['profiles', 'tasks', 'dose_owner', 'emergency_contacts', 'settings'];
  static const _dayTables = [
    'day_off_work',
    'night_cover',
    'ticks',
    'dose_records',
    'notes',
    'reviews',
    'shopping_items',
    'shopping_lists',
    'time_logs',
  ];

  /// Fetches everything again and lays unsent changes on top.
  Future<void> reload() async {
    final s = session;
    if (s == null) return;
    final List<List<Map<String, dynamic>>> results;
    try {
      results = await Future.wait([
        for (final t in _sharedTables) _fetch(t),
        for (final t in _dayTables) _fetch(t, byDay: true),
      ]);
    } catch (_) {
      _setOnline(false);
      return;
    }
    _setOnline(true);
    _clear();
    final tables = [..._sharedTables, ..._dayTables];
    for (var i = 0; i < tables.length; i++) {
      for (final row in results[i]) {
        _applyUpsert(tables[i], row, sent: true);
      }
    }
    for (final op in outbox.pending) {
      _apply(op);
    }
    user = people.where((p) => p.id == s.user.id).firstOrNull;
    notifyListeners();
  }

  void _clear() {
    people.clear();
    tasks.clear();
    doseOwner.updateAll((_, _) => null);
    for (final m in [dayOffWork, covers, ticks, doses, notes, reviews, shopping, timeLogs, settings]) {
      m.clear();
    }
    contacts.clear();
  }

  void _apply(Op op) {
    switch (op.kind) {
      case 'upsert':
        _applyUpsert(op.table, op.data, sent: false);
      case 'update':
        final match = (op.data['match'] as Map).cast<String, dynamic>();
        final values = (op.data['values'] as Map).cast<String, dynamic>();
        _applyUpdate(op.table, match, values);
      case 'delete':
        _applyDelete(op.table, op.data);
    }
  }

  void _applyUpsert(String table, Map<String, dynamic> row, {required bool sent}) {
    final day = row['day'] as String?;
    switch (table) {
      case 'profiles':
        people.removeWhere((p) => p.id == row['id']);
        people.add(Person.fromRow(row));
      case 'tasks':
        tasks.removeWhere((t) => t.id == row['id']);
        tasks.add(Task.fromRow(row));
      case 'dose_owner':
        doseOwner[Dose.values.byName(row['dose'] as String)] = row['person_id'] as String?;
      case 'day_off_work':
        dayOffWork.putIfAbsent(day!, () => {})[row['person_id'] as String] = DayOffWork(
          row['compensation'] == 'extraPay' ? Compensation.extraPay : Compensation.dayOff,
          row['note'] as String? ?? '',
        );
      case 'night_cover':
        final c = NightCover.fromRow(row);
        covers.putIfAbsent(day!, () => {})[c.restingId] = c;
      case 'ticks':
        final t = Tick.fromRow(row);
        final local = Tick(
          day: t.day,
          seriesId: t.seriesId,
          personId: t.personId,
          byId: t.byId,
          time: t.time,
          done: t.done,
          reason: t.reason,
          vitals: t.vitals,
          photos: [for (final p in t.photos) _withBytes(p)],
          sent: sent,
        );
        ticks.putIfAbsent(day!, () => {})[t.seriesId] = local;
      case 'dose_records':
        final r = DoseRecord.fromRow(row);
        final local = DoseRecord(
          id: r.id,
          day: r.day,
          dose: r.dose,
          parent: r.parent,
          byId: r.byId,
          time: r.time,
          photo: r.photo == null ? null : _withBytes(r.photo!),
          sent: sent,
        );
        final list = doses.putIfAbsent(day!, () => {}).putIfAbsent('${r.dose.name}/${r.parent.name}', () => []);
        list
          ..removeWhere((x) => x.id == r.id)
          ..add(local);
      case 'notes':
        notes.putIfAbsent(day!, () => {})[row['series_id'] as String] = TaskNote(
          row['text'] as String,
          row['by_id'] as String,
          DateTime.parse(row['at'] as String).toLocal(),
          sent,
        );
      case 'reviews':
        reviews.putIfAbsent(day!, () => {})[row['person_id'] as String] = Review(
          row['status'] == 'sentBack' ? ReviewStatus.sentBack : ReviewStatus.confirmed,
          row['by_id'] as String,
          DateTime.parse(row['at'] as String).toLocal(),
          row['note'] as String? ?? '',
        );
      case 'shopping_items':
        final items = shoppingList(DateTime.parse(day!)).items;
        items.removeWhere((i) => i.id == row['id']);
        items.add(ShopItem(row['id'] as String, row['name'] as String, row['qty'] as String? ?? '', row['bought'] as bool, sent));
      case 'shopping_lists':
        final list = shoppingList(DateTime.parse(day!));
        final at = row['handed_over'] == null ? null : DateTime.parse(row['handed_over'] as String).toLocal();
        list.handedOver = at;
        if (sent) list.handedOverSent = at;
      case 'time_logs':
        timeLogs[row['id'] as String] = TimeLog.fromRow(row)..sent = sent;
      case 'emergency_contacts':
        contacts
          ..removeWhere((c) => c.id == row['id'])
          ..add(Contact.fromRow(row))
          ..sort((a, b) => a.sort.compareTo(b.sort));
      case 'settings':
        settings[row['key'] as String] = row['value'] as String;
    }
  }

  void _applyUpdate(String table, Map<String, dynamic> match, Map<String, dynamic> values) {
    switch (table) {
      case 'profiles':
        final p = people.where((p) => p.id == match['id']).firstOrNull;
        if (p == null) return;
        if (values.containsKey('name')) p.name = values['name'] as String;
        if (values.containsKey('duties')) p.duties = values['duties'] as String;
        if (values.containsKey('hours')) p.hours = values['hours'] as String;
        if (values.containsKey('phone')) p.phone = values['phone'] as String;
        if (values.containsKey('day_off')) p.dayOff = values['day_off'] as int?;
      case 'dose_owner':
        doseOwner[Dose.values.byName(match['dose'] as String)] = values['person_id'] as String?;
    }
  }

  void _applyDelete(String table, Map<String, dynamic> m) {
    final day = m['day'] as String?;
    switch (table) {
      case 'tasks':
        tasks.removeWhere((t) => t.id == m['id']);
      case 'day_off_work':
        dayOffWork[day]?.remove(m['person_id']);
      case 'night_cover':
        covers[day]?.remove(m['resting_id']);
      case 'ticks':
        ticks[day]?.remove(m['series_id']);
      case 'dose_records':
        for (final forDay in doses.values) {
          for (final list in forDay.values) {
            list.removeWhere((r) => r.id == m['id']);
          }
        }
      case 'notes':
        notes[day]?.remove(m['series_id']);
      case 'reviews':
        reviews[day]?.remove(m['person_id']);
      case 'shopping_items':
        for (final list in shopping.values) {
          list.items.removeWhere((i) => i.id == m['id']);
        }
      case 'time_logs':
        timeLogs.remove(m['id']);
      case 'emergency_contacts':
        contacts.removeWhere((c) => c.id == m['id']);
    }
  }

  Photo _withBytes(Photo p) => Photo(path: p.path, label: p.label, bytes: outbox.photo(p.path));

  /// Saves [ops] on the phone, shows them at once and tries to send them.
  Future<void> _save(List<Op> ops) async {
    for (final op in ops) {
      await outbox.add(op);
      _apply(op);
    }
    notifyListeners();
    unawaited(sync());
  }

  final Map<String, Future<String?>> _urls = {};

  /// A short-lived link to a proof photo in storage.
  Future<String?> photoUrl(String path) => _urls.putIfAbsent(path, () async {
    try {
      return await db.storage.from(Config.photoBucket).createSignedUrl(path, 3600);
    } catch (_) {
      _urls.remove(path);
      return null;
    }
  });

  int get waitingToSend => outbox.length;

  // -------------------------------------------------------------- people

  List<Person> get activePeople => people.where((p) => p.removedFrom == null && !p.isPending).toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  /// Maids on the team on [day].
  List<Person> maidsOn(DateTime day) => people.where((p) {
    if (p.isAdmin || p.isPending) return false;
    final removed = p.removedFrom;
    return !day.isBefore(p.since) && (removed == null || day.isBefore(removed));
  }).toList()..sort((a, b) => a.name.compareTo(b.name));

  List<Person> get admins => activePeople.where((p) => p.isAdmin).toList();

  Person person(String id) =>
      people.where((p) => p.id == id).firstOrNull ??
      Person(id: id, name: 'Someone', isAdmin: false, since: DateTime(2000));

  /// Whether [p] keeps a shopping list (has a task with the shopping button).
  bool keepsShopping(String personId) => tasksFor(personId).any((t) => t.shopping);

  /// Creates an account. Returns an error to show, or null when done.
  Future<String?> createPerson({
    required String name,
    required String email,
    required String password,
    required String phone,
    required bool isAdmin,
    String duties = '',
    String hours = '',
    String? template,
    String? copyFrom,
  }) async {
    final String id;
    try {
      final res = await db.functions.invoke(
        'manage-user',
        body: {
          'action': 'create',
          'email': email.trim(),
          'password': password,
          'name': name,
          'role': isAdmin ? 'admin' : 'maid',
          'phone': phone,
          'duties': duties,
          'hours': hours,
        },
      );
      id = (res.data as Map)['id'] as String;
    } on FunctionException catch (e) {
      return (e.details is Map ? (e.details as Map)['error'] : null)?.toString() ?? 'Could not add.';
    } catch (_) {
      return 'No internet. Adding someone needs the internet.';
    }
    final newTasks = template != null
        ? templateTasks(template, id, today, newUuid)
        : [
            if (copyFrom != null)
              for (final t in tasksFor(copyFrom))
                t.copy()
                  ..id = newUuid()
                  ..ownerId = id
                  ..validFrom = today
                  ..validUntil = null,
          ];
    // A copied task needs its own series.
    final ops = [
      for (final t in newTasks) Op.upsert('tasks', (t.toRow()..['series_id'] = t.id)),
      if (copyFrom != null && person(copyFrom).dayOff != null)
        Op.update('profiles', {'id': id}, {'day_off': person(copyFrom).dayOff}),
    ];
    await reload();
    await _save(ops);
    return null;
  }

  void updatePerson(Person p, {required String name, required String duties, required String hours, required String phone}) =>
      _save([Op.update('profiles', {'id': p.id}, {'name': name, 'duties': duties, 'hours': hours, 'phone': phone})]);

  Future<String?> _manage(Map<String, dynamic> body) async {
    try {
      await db.functions.invoke('manage-user', body: body);
      await reload();
      return null;
    } on FunctionException catch (e) {
      return (e.details is Map ? (e.details as Map)['error'] : null)?.toString() ?? 'Could not do that.';
    } catch (_) {
      return 'No internet. This needs the internet.';
    }
  }

  Future<String?> resetPassword(Person p, String password) =>
      _manage({'action': 'reset_password', 'id': p.id, 'password': password});

  Future<String?> removePerson(Person p) async {
    final error = await _manage({'action': 'remove', 'id': p.id, 'from': dayKey(today)});
    if (error != null) return error;
    // Their tasks end today; earlier days keep them.
    final series = tasks.where((t) => t.ownerId == p.id).map((t) => t.seriesId).toSet();
    await _save([
      for (final s in series) ..._endSeries(s, today),
      for (final d in Dose.values)
        if (doseOwner[d] == p.id) Op.update('dose_owner', {'dose': d.name}, {'person_id': null}),
    ]);
    return null;
  }

  /// Why [p] cannot be removed, or null if they can.
  String? cannotRemove(Person p) {
    if (p.id == user?.id) return 'You cannot remove yourself.';
    if (p.isAdmin && admins.length == 1) return 'There must always be at least one admin.';
    return null;
  }

  // ----------------------------------------------------------- schedules

  /// The versions of [owner]'s tasks in force on [day], by start time.
  List<Task> tasksFor(String owner, [DateTime? day]) {
    final d = day ?? today;
    return tasks.where((t) {
      if (t.ownerId != owner) return false;
      final from = t.validFrom;
      final until = t.validUntil;
      return (from == null || !d.isBefore(from)) && (until == null || !d.isAfter(until));
    }).toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  /// Ends a task series the day before [from], dropping versions that would
  /// have started on or after it.
  List<Op> _endSeries(String seriesId, DateTime from) {
    final dayBefore = from.subtract(const Duration(days: 1));
    return [
      for (final t in tasks.where((t) => t.seriesId == seriesId))
        if (t.validFrom != null && !t.validFrom!.isBefore(from))
          Op.delete('tasks', {'id': t.id})
        else if (t.validUntil == null || t.validUntil!.isAfter(dayBefore))
          Op.upsert('tasks', (t.copy()..validUntil = dayBefore).toRow()),
    ];
  }

  /// Saves [task] as a new version starting on [from].
  void saveTask(Task task, DateTime from) {
    final ops = _endSeries(task.seriesId, from);
    task
      ..id = '${task.seriesId}@${dayKey(from)}'
      ..validFrom = from
      ..validUntil = null;
    _save([...ops, Op.upsert('tasks', task.toRow())]);
  }

  void removeTask(String seriesId, DateTime from) => _save(_endSeries(seriesId, from));

  /// Schedule changes for [owner] that start after today.
  List<UpcomingChange> upcomingChanges(String owner) {
    final changes = <UpcomingChange>[];
    final bySeries = <String, List<Task>>{};
    for (final t in tasks.where((t) => t.ownerId == owner)) {
      bySeries.putIfAbsent(t.seriesId, () => []).add(t);
    }
    for (final versions in bySeries.values) {
      for (final v in versions) {
        final from = v.validFrom;
        if (from == null || !from.isAfter(today)) continue;
        final replaces = versions.any((o) {
          final until = o.validUntil;
          return o != v && until != null && until.add(const Duration(days: 1)) == from;
        });
        changes.add(UpcomingChange(from, v, replaces ? ChangeType.changed : ChangeType.added));
      }
      final last = versions.reduce(
        (a, b) => (a.validFrom ?? DateTime(0)).isAfter(b.validFrom ?? DateTime(0)) ? a : b,
      );
      final until = last.validUntil;
      if (until != null && !until.isBefore(today)) {
        changes.add(UpcomingChange(until.add(const Duration(days: 1)), last, ChangeType.removed));
      }
    }
    changes.sort((a, b) => a.date.compareTo(b.date));
    return changes;
  }

  void cancelChange(UpcomingChange change) {
    final t = change.task;
    switch (change.type) {
      case ChangeType.removed:
        _save([Op.upsert('tasks', (t.copy()..validUntil = null).toRow())]);
      case ChangeType.added:
      case ChangeType.changed:
        _save([
          Op.delete('tasks', {'id': t.id}),
          for (final o in tasks.where((o) => o.seriesId == t.seriesId && o != t))
            if (o.validUntil != null && o.validUntil!.add(const Duration(days: 1)) == t.validFrom)
              Op.upsert('tasks', (o.copy()..validUntil = t.validUntil).toRow()),
        ]);
    }
  }

  String newTaskId() => newUuid();

  DayOffWork? dayOffWorkOn(String personId, DateTime day) => dayOffWork[dayKey(day)]?[personId];

  void setDayOffWork(String personId, DateTime day, DayOffWork? work) => _save([
    work == null
        ? Op.delete('day_off_work', {'day': dayKey(day), 'person_id': personId})
        : Op.upsert('day_off_work', {
            'day': dayKey(day),
            'person_id': personId,
            'compensation': work.compensation.name,
            'note': work.note,
          }),
  ]);

  void setDayOff(String personId, int? weekday) =>
      _save([Op.update('profiles', {'id': personId}, {'day_off': weekday})]);

  void setDoseOwner(Dose dose, String? personId) =>
      _save([Op.update('dose_owner', {'dose': dose.name}, {'person_id': personId})]);

  bool isDayOff(String personId, DateTime day) =>
      person(personId).dayOff == day.weekday && dayOffWorkOn(personId, day) == null;

  // ------------------------------------------------------- night cover

  NightCover? coverFor(String restingId, DateTime day) => covers[dayKey(day)]?[restingId];

  /// Who rests on [day] while [personId] covers for them.
  List<NightCover> coveredBy(String personId, DateTime day) =>
      (covers[dayKey(day)]?.values ?? const <NightCover>[]).where((c) => c.coveringId == personId).toList();

  /// The morning after a night emergency: before 6 AM that is today.
  DateTime get coverDay => now.hour < 6 ? today : today.add(const Duration(days: 1));

  void logNightEmergency({required String restingId, required String coveringId, required String note}) => _save([
    Op.upsert(
      'night_cover',
      NightCover(day: coverDay, restingId: restingId, coveringId: coveringId, note: note, loggedBy: user!.id).toRow(),
    ),
  ]);

  void cancelCover(NightCover c) =>
      _save([Op.delete('night_cover', {'day': dayKey(c.day), 'resting_id': c.restingId})]);

  /// [personId]'s checklist for [day], with any morning they cover.
  List<Task> tasksOn(String personId, DateTime day) {
    final own = isDayOff(personId, day)
        ? <Task>[]
        : tasksFor(personId, day).where((t) => t.days.contains(day.weekday)).toList();
    final resting = coverFor(personId, day);
    if (resting != null) own.removeWhere((t) => t.start < resting.untilMin);
    for (final c in coveredBy(personId, day)) {
      if (isDayOff(c.restingId, day)) continue;
      own.addAll(
        tasksFor(c.restingId, day).where((t) => t.days.contains(day.weekday) && t.start < c.untilMin),
      );
    }
    return own..sort((a, b) => a.start.compareTo(b.start));
  }

  // ---------------------------------------------------------------- ticks

  Tick? tickFor(Task task, DateTime day) => ticks[dayKey(day)]?[task.seriesId];

  TaskNote? noteFor(Task task, DateTime day) => notes[dayKey(day)]?[task.seriesId];

  void saveNote(Task task, DateTime day, String text) {
    final trimmed = text.trim();
    _save([
      trimmed.isEmpty
          ? Op.delete('notes', {'day': dayKey(day), 'series_id': task.seriesId})
          : Op.upsert('notes', {
              'day': dayKey(day),
              'series_id': task.seriesId,
              'by_id': user!.id,
              'text': trimmed,
              'at': now.toUtc().toIso8601String(),
            }),
    ]);
  }

  int noteCount(String personId, DateTime day) =>
      tasksOn(personId, day).where((t) => noteFor(t, day) != null).length;

  TaskState stateOf(Task task, DateTime day) {
    if (task.kind == TaskKind.rest) return TaskState.rest;
    final tick = tickFor(task, day);
    if (tick != null) return tick.done ? TaskState.done : TaskState.missed;
    if (day.isBefore(today)) return TaskState.missed;
    if (day.isAfter(today)) return TaskState.upcoming;
    final minute = nowMinute;
    if (minute >= task.end) return TaskState.missed;
    if (minute >= task.start) return TaskState.now;
    return TaskState.upcoming;
  }

  /// Keeps [bytes] on the phone until sent; returns where it will live.
  Future<Photo> _keepPhoto(Uint8List bytes, DateTime day, String label) async {
    final path = '${user!.id}/${dayKey(day)}/${newUuid()}.jpg';
    await outbox.keepPhoto(path, bytes);
    return Photo(path: path, label: label);
  }

  /// Marks [task] done with its proof photos.
  Future<void> tick(
    Task task,
    DateTime day, {
    required List<Uint8List> photos,
    Map<Parent, Vitals>? vitals,
  }) async {
    final kept = [
      for (final (i, b) in photos.indexed) await _keepPhoto(b, day, '${task.title}, photo ${i + 1}'),
    ];
    final t = Tick(
      day: day,
      seriesId: task.seriesId,
      personId: task.ownerId,
      byId: user!.id,
      time: now,
      vitals: vitals,
      photos: kept,
    );
    await _save([Op.upsert('ticks', t.toRow(), photos: [for (final p in kept) p.path])]);
  }

  /// Logs that [task] could not be done, and why. It still counts as missed.
  void notDone(Task task, DateTime day, String reason) => _save([
    Op.upsert(
      'ticks',
      Tick(
        day: day,
        seriesId: task.seriesId,
        personId: task.ownerId,
        byId: user!.id,
        time: now,
        done: false,
        reason: reason,
      ).toRow(),
    ),
  ]);

  /// A tick can be undone while online, or while it is still on this phone.
  bool canUndo(Task task, DateTime day) {
    final tick = tickFor(task, day);
    return tick != null && tick.byId == user?.id && (online || !tick.sent);
  }

  void undoTick(Task task, DateTime day) =>
      _save([Op.delete('ticks', {'day': dayKey(day), 'series_id': task.seriesId})]);

  // ------------------------------------------------------------ medicines

  DoseRecord? doseRecord(Dose dose, Parent parent, DateTime day) {
    final records = [...?doses[dayKey(day)]?['${dose.name}/${parent.name}']]
      ..sort((a, b) => a.time.compareTo(b.time));
    return records.isEmpty ? null : records.first;
  }

  /// Records a dose with its photo as proof.
  Future<void> giveDose(Dose dose, Parent parent, DateTime day, Uint8List photo) async {
    if (doseRecord(dose, parent, day) != null) return;
    final kept = await _keepPhoto(photo, day, '${dose.label}, ${parent.label}');
    final r = DoseRecord(
      id: newUuid(),
      day: day,
      dose: dose,
      parent: parent,
      byId: user!.id,
      time: now,
      photo: kept,
    );
    await _save([Op.upsert('dose_records', r.toRow(), photos: [kept.path])]);
  }

  /// Doses recorded by two maids whose phones could not see each other.
  List<DoubleDose> doubleDoses(DateTime day) {
    final found = <DoubleDose>[];
    for (final dose in Dose.values) {
      for (final parent in Parent.values) {
        final records = [...?doses[dayKey(day)]?['${dose.name}/${parent.name}']].where((r) => r.sent).toList()
          ..sort((a, b) => a.time.compareTo(b.time));
        if (records.length > 1) found.add(DoubleDose(dose, parent, records));
      }
    }
    return found;
  }

  /// When [dose] should be given by on [day]: the latest end of its tasks.
  int? doseDueBy(Dose dose, DateTime day) {
    int? due;
    for (final maid in maidsOn(day)) {
      for (final t in tasksOn(maid.id, day)) {
        if (t.kind == TaskKind.medicine && t.dose == dose && (due == null || t.end > due)) {
          due = t.end;
        }
      }
    }
    return due;
  }

  /// Doses that are due and nobody recorded.
  List<MissingDose> missingDoses(DateTime day) {
    final missing = <MissingDose>[];
    final notPast = !day.isBefore(today);
    for (final dose in Dose.values) {
      final due = doseDueBy(dose, day);
      if (due == null) continue;
      if (notPast && (day.isAfter(today) || nowMinute < due)) continue;
      for (final parent in Parent.values) {
        if (doseRecord(dose, parent, day) == null) missing.add(MissingDose(due, dose, parent));
      }
    }
    return missing;
  }

  /// Medicine doses the signed-in maid should give now.
  List<MedicineReminder> get dueReminders {
    final me = user;
    if (me == null || me.isAdmin) return const [];
    final minute = nowMinute;
    final due = <MedicineReminder>[];
    for (final task in tasksOn(me.id, today)) {
      final dose = task.dose;
      if (task.kind != TaskKind.medicine || dose == null) continue;
      if (minute < task.start || minute >= task.end) continue;
      final owner = doseOwner[dose];
      if (owner != null && owner != me.id) continue;
      final parents = Parent.values.where((p) => doseRecord(dose, p, today) == null).toList();
      final key = '${dayKey(today)}/${task.seriesId}';
      final until = snoozed[key];
      if (parents.isEmpty || (until != null && now.isBefore(until))) continue;
      due.add(MedicineReminder(task, dose, parents, key));
    }
    return due;
  }

  void snooze(String key) {
    snoozed[key] = now.add(const Duration(minutes: 10));
    notifyListeners();
  }

  // ------------------------------------------------------------- progress

  Progress progress(String personId, DateTime day) {
    var done = 0, missed = 0, total = 0, weightDone = 0, weightLost = 0, weightTotal = 0;
    for (final t in tasksOn(personId, day)) {
      final state = stateOf(t, day);
      if (state == TaskState.rest) continue;
      total++;
      weightTotal += t.weight;
      if (state == TaskState.done) {
        done++;
        weightDone += t.weight;
      } else if (state == TaskState.missed) {
        missed++;
        weightLost += t.weight;
      }
    }
    return Progress(done, missed, total, weightDone, weightLost, weightTotal);
  }

  /// Missed tasks over the [days] days before today.
  int missesIn(String personId, int days) {
    var count = 0;
    for (var i = 1; i <= days; i++) {
      final d = today.subtract(Duration(days: i));
      if (d.isBefore(person(personId).since) || d.isBefore(_from)) break;
      count += progress(personId, d).missed;
    }
    return count;
  }

  /// Repeated misses move a maid to the next phase.
  Phase phaseOf(String personId) {
    if (missesIn(personId, 30) >= 10) return Phase.action;
    if (missesIn(personId, 14) >= 6) return Phase.finalWarning;
    if (missesIn(personId, 7) >= 3) return Phase.warning;
    return Phase.none;
  }

  /// The task [personId] should be on right now.
  Task? currentTask(String personId, DateTime day) {
    if (day != today) return null;
    final minute = nowMinute;
    for (final t in tasksOn(personId, day)) {
      if (minute >= t.start && minute < t.end) return t;
    }
    return null;
  }

  Review? reviewOf(String personId, DateTime day) => reviews[dayKey(day)]?[personId];

  void setReview(String personId, DateTime day, ReviewStatus? status, [String note = '']) => _save([
    status == null
        ? Op.delete('reviews', {'day': dayKey(day), 'person_id': personId})
        : Op.upsert('reviews', {
            'day': dayKey(day),
            'person_id': personId,
            'status': status.name,
            'by_id': user!.id,
            'at': now.toUtc().toIso8601String(),
            'note': note,
          }),
  ]);

  // ------------------------------------------------------- breaks, free time

  List<TimeLog> logsOn(String personId, DateTime day) =>
      timeLogs.values.where((l) => l.personId == personId && l.day == day).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  /// The break or free time [personId] is on right now.
  TimeLog? openLog(String personId) =>
      logsOn(personId, today).where((l) => l.end == null).firstOrNull;

  Duration timeOn(String personId, DateTime day, TimeKind kind) => logsOn(personId, day)
      .where((l) => l.kind == kind)
      .fold(Duration.zero, (sum, l) => sum + l.lengthUntil(now));

  void startLog(TimeKind kind) {
    final open = openLog(user!.id);
    _save([
      if (open != null) Op.upsert('time_logs', (open..end = now).toRow()),
      Op.upsert(
        'time_logs',
        TimeLog(id: newUuid(), personId: user!.id, day: today, kind: kind, start: now).toRow(),
      ),
    ]);
  }

  void endLog() {
    final open = openLog(user!.id);
    if (open == null) return;
    _save([Op.upsert('time_logs', (open..end = now).toRow())]);
  }

  // ------------------------------------------------------------- shopping

  bool get viewerIsAdmin => user?.isAdmin != false;

  ShoppingList shoppingList(DateTime day) => shopping.putIfAbsent(dayKey(day), ShoppingList.new);

  List<ShopItem> shoppingItems(DateTime day) => [...shoppingList(day).items];

  Map<String, dynamic> _itemRow(DateTime day, ShopItem i) => {
    'id': i.id,
    'day': dayKey(day),
    'name': i.name,
    'qty': i.qty,
    'bought': i.bought,
    'created_by': user!.id,
  };

  void addShopItem(DateTime day, String name, String qty) =>
      _save([Op.upsert('shopping_items', _itemRow(day, ShopItem(newUuid(), name, qty, false, false)))]);

  void removeShopItem(DateTime day, ShopItem item) => _save([Op.delete('shopping_items', {'id': item.id})]);

  void toggleBought(DateTime day, ShopItem item) =>
      _save([Op.upsert('shopping_items', _itemRow(day, item)..['bought'] = !item.bought)]);

  void handOver(DateTime day, bool handedOver) => _save([
    Op.upsert('shopping_lists', {
      'day': dayKey(day),
      'handed_over': handedOver ? now.toUtc().toIso8601String() : null,
    }),
  ]);

  // ----------------------------------------------------------- emergencies

  static const defaultSop = '''
1. Stay calm. Make sure Mama and Papa are safe and not alone.
2. If someone is not breathing, unconscious, bleeding badly, has chest pain or a bad fall: call 998 (ambulance) at once.
3. Fire or smoke: get everyone out, then call 997.
4. Call Boss. No answer: call Cielo, then Dei. Keep calling until someone answers.
5. Mid-level problem (fever, small fall, refused medicine, vomiting): call the family doctor, then message the family WhatsApp group with what happened and the time.
6. Do not give any medicine that is not on the schedule unless the doctor says so.
7. Write what happened as a note in the app, with the time.
8. If you were up at night, log a night emergency in the app so the other maid covers your morning and you can rest.''';

  String get sop => settings['sop']?.trim().isNotEmpty == true ? settings['sop']! : defaultSop;

  void saveSop(String text) => _save([Op.upsert('settings', {'key': 'sop', 'value': text})]);

  void saveContact(Contact c) => _save([Op.upsert('emergency_contacts', c.toRow())]);

  void deleteContact(Contact c) => _save([Op.delete('emergency_contacts', {'id': c.id})]);

  // ------------------------------------------------------------- history

  /// Sees an earlier day, loading it the first time.
  void openDay(DateTime day) {
    if (day.isBefore(_from)) {
      _from = day;
      reload();
    }
  }

  // ---------------------------------------------------------- reminders

  /// Saves this phone's push address if reminders are already allowed.
  Future<void> registerPushIfAllowed() async {
    final address = await currentPush(Config.vapidPublicKey);
    if (address != null) await _savePush(address);
  }

  /// Asks for permission and turns on reminders on this phone.
  Future<bool> enablePush() async {
    try {
      final address = await subscribePush(Config.vapidPublicKey);
      if (address == null) return false;
      await _savePush(address);
      _say('Reminders are on for this phone.');
      notifyListeners();
      return true;
    } catch (_) {
      _say('Could not turn on reminders on this phone.');
      return false;
    }
  }

  Future<void> _savePush(PushAddress a) async {
    final me = user;
    if (me == null) return;
    await _save([
      Op.upsert('push_subscriptions', {
        'endpoint': a.endpoint,
        'person_id': me.id,
        'p256dh': a.p256dh,
        'auth': a.auth,
      }),
    ]);
  }
}

/// Gives every screen below it the [AppState].
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
