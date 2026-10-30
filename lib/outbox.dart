import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';

/// One change waiting to reach Supabase.
class Op {
  Op.upsert(this.table, Map<String, dynamic> row, {this.photos = const []}) : kind = 'upsert', data = row;
  Op.delete(this.table, Map<String, dynamic> match) : kind = 'delete', data = match, photos = const [];

  /// Changes [values] on the row matching [match], for tables where only
  /// updates are allowed (profiles, dose_owner).
  Op.update(this.table, Map<String, dynamic> match, Map<String, dynamic> values)
    : kind = 'update',
      data = {'match': match, 'values': values},
      photos = const [];

  Op._(this.kind, this.table, this.data, this.photos);

  factory Op.fromJson(Map<String, dynamic> j) => Op._(
    j['kind'] as String,
    j['table'] as String,
    (j['data'] as Map).cast<String, dynamic>(),
    (j['photos'] as List).cast<String>(),
  );

  final String kind;
  final String table;
  final Map<String, dynamic> data;

  /// Storage paths to upload before the row is written.
  final List<String> photos;

  Map<String, dynamic> toJson() => {'kind': kind, 'table': table, 'data': data, 'photos': photos};
}

/// Changes made on this phone, kept until they are sent, so nothing is lost
/// on weak Wi-Fi or if the app is closed.
class Outbox {
  late final Box<String> _ops;
  late final Box<Uint8List> _photos;

  static Future<Outbox> open() async {
    await Hive.initFlutter();
    final box = Outbox();
    box._ops = await Hive.openBox<String>('outbox');
    box._photos = await Hive.openBox<Uint8List>('photos');
    return box;
  }

  List<Op> get pending => [for (final s in _ops.values) Op.fromJson(jsonDecode(s) as Map<String, dynamic>)];

  int get length => _ops.length;

  Future<void> add(Op op) => _ops.add(jsonEncode(op.toJson()));

  Future<void> keepPhoto(String path, Uint8List bytes) => _photos.put(path, bytes);

  /// A photo still on this phone, if it has not been sent yet.
  Uint8List? photo(String path) => _photos.get(path);

  /// Sends what it can, in order. Stops at the first network failure and
  /// returns false; a change the server refuses is dropped and reported.
  Future<bool> flush(SupabaseClient db, void Function(String) onRefused) async {
    while (_ops.isNotEmpty) {
      final key = _ops.keys.first;
      final op = Op.fromJson(jsonDecode(_ops.get(key)!) as Map<String, dynamic>);
      try {
        for (final path in op.photos) {
          final bytes = _photos.get(path);
          if (bytes == null) continue;
          await db.storage
              .from(Config.photoBucket)
              .uploadBinary(path, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true));
        }
        final table = db.from(op.table);
        if (op.kind == 'upsert') {
          await table.upsert(op.data);
        } else if (op.kind == 'update') {
          var query = table.update((op.data['values'] as Map).cast<String, dynamic>());
          for (final e in (op.data['match'] as Map).entries) {
            query = query.eq(e.key as String, e.value as Object);
          }
          await query;
        } else {
          var query = table.delete();
          for (final e in op.data.entries) {
            query = query.eq(e.key, e.value as Object);
          }
          await query;
        }
        for (final path in op.photos) {
          await _photos.delete(path);
        }
        await _ops.delete(key);
      } on PostgrestException catch (e) {
        onRefused(e.message);
        await _ops.delete(key);
      } on StorageException catch (e) {
        onRefused(e.message);
        await _ops.delete(key);
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  Future<void> clear() async {
    await _ops.clear();
    await _photos.clear();
  }
}

final _random = Random.secure();

/// A random v4 UUID, so rows made offline get their final id at once.
String newUuid() {
  final b = List<int>.generate(16, (_) => _random.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}
