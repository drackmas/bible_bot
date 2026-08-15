import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/translation.dart';

class TranslationService {
  static const String defaultTranslation = 'KJV';

  static List<BibleTranslation>? _translations;

  static Future<List<BibleTranslation>> load() async {
    if (_translations != null) {
      return _translations!;
    }

    final file = File(
      p.join('assets', 'referencebibles.json'),
    );

    if (!await file.exists()) {
      throw StateError(
        'assets/referencebibles.json was not found.',
      );
    }

    final decoded = jsonDecode(
      await file.readAsString(),
    );

    if (decoded is! List) {
      throw StateError(
        'assets/referencebibles.json must contain a JSON array.',
      );
    }

    _translations = decoded
        .whereType<Map>()
        .map(
          (item) => BibleTranslation.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .where(
          (translation) => translation.id.isNotEmpty,
        )
        .toList();

    return _translations!;
  }

  static Future<BibleTranslation> get(
    String id,
  ) async {
    final translations = await load();

    final normalized = id.trim().toLowerCase();

    for (final translation in translations) {
      if (translation.id.toLowerCase() == normalized) {
        return translation;
      }
    }

    throw StateError(
      'Unknown Bible translation `$id`.',
    );
  }

  static Future<bool> exists(
    String id,
  ) async {
    try {
      await get(id);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<String> normalize(
    String? id,
  ) async {
    if (id == null || id.trim().isEmpty) {
      return defaultTranslation;
    }

    final translation = await get(id);

    return translation.id;
  }

  static Future<String> getDisplayName(
    String id,
  ) async {
    final translation = await get(id);

    return translation.name;
  }
}
