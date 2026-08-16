import 'dart:convert';
import 'dart:io';

const String baseUrl =
    'https://raw.githubusercontent.com/'
    'drackmas/me_bible/v1.3/assets';

const String akjvPath = 'assets/AKJV.json';

const String outputPath = 'assets/KJV-edit.json';

Future<void> main() async {
  final client = HttpClient();

  try {
    stdout.writeln(
      'Loading canonical book names from '
      '$akjvPath...',
    );

    final akjvFile = File(akjvPath);

    if (!await akjvFile.exists()) {
      throw FileSystemException('AKJV.json was not found.', akjvPath);
    }

    final akjvText = await akjvFile.readAsString();

    final akjv = jsonDecode(akjvText);

    if (akjv is! Map) {
      throw const FormatException('AKJV.json must contain a JSON object.');
    }

    final akjvBooks = akjv['books'];

    if (akjvBooks is! List) {
      throw const FormatException('AKJV.json is missing "books".');
    }

    if (akjvBooks.isEmpty) {
      throw const FormatException('AKJV.json contains no books.');
    }

    stdout.writeln('Found ${akjvBooks.length} canonical books.');
    stdout.writeln('');

    /*
     * AKJV.json is authoritative for:
     *
     * - output book names
     * - output book order
     *
     * me_bible is authoritative for:
     *
     * - source Bible text
     * - source filenames
     */

    final canonicalBooks = <String>[];

    for (final book in akjvBooks) {
      if (book is! Map) {
        throw const FormatException('Invalid book entry in AKJV.json.');
      }

      final name = book['name']?.toString().trim();

      if (name == null || name.isEmpty) {
        throw const FormatException('A book in AKJV.json is missing "name".');
      }

      canonicalBooks.add(name);
    }

    final outputBooks = <Map<String, dynamic>>[];

    var totalChapters = 0;
    var totalVerses = 0;

    for (final canonicalName in canonicalBooks) {
      final sourceFileName = await findSourceFileName(client, canonicalName);

      stdout.write(
        'Downloading '
        '$sourceFileName.json '
        '→ "$canonicalName"... ',
      );

      final source = await downloadJson(
        client,
        '$baseUrl/$sourceFileName.json',
      );

      final converted = convertBook(source, canonicalName);

      outputBooks.add(converted);

      final chapters = converted['chapters'] as List;

      var bookVerses = 0;

      for (final chapter in chapters) {
        final verses = chapter['verses'] as List;

        bookVerses += verses.length;
      }

      totalChapters += chapters.length;
      totalVerses += bookVerses;

      stdout.writeln(
        'OK '
        '(${chapters.length} chapters, '
        '$bookVerses verses)',
      );
    }

    final output = {'books': outputBooks};

    const encoder = JsonEncoder.withIndent('    ');

    final outputFile = File(outputPath);

    await outputFile.writeAsString('${encoder.convert(output)}\n');

    stdout.writeln('');
    stdout.writeln('========================================');
    stdout.writeln('Conversion complete.');
    stdout.writeln('========================================');
    stdout.writeln('Books:    ${outputBooks.length}');
    stdout.writeln('Chapters: $totalChapters');
    stdout.writeln('Verses:   $totalVerses');
    stdout.writeln('Output:   $outputPath');

    verifyBookNames(akjvBooks, outputBooks);

    stdout.writeln('');
    stdout.writeln('Book-name verification: PASSED');
    stdout.writeln(
      'KJV-edit.json matches AKJV.json '
      'book names and order.',
    );
  } catch (error, stackTrace) {
    stderr.writeln('');
    stderr.writeln('ERROR: $error');
    stderr.writeln('');
    stderr.writeln(stackTrace);

    exitCode = 1;
  } finally {
    client.close();
  }
}

Future<String> findSourceFileName(
  HttpClient client,
  String canonicalName,
) async {
  /*
   * Try the exact name first.
   *
   * Example:
   *
   * Genesis → Genesis.json
   * Revelation → Revelation.json
   */
  final exactCandidates = <String>[canonicalName];

  /*
   * me_bible uses Arabic numbers in filenames
   * while your AKJV uses Roman numerals for
   * some books.
   *
   * Examples:
   *
   * I Samuel  → 1Samuel
   * II Samuel → 2Samuel
   * III John  → 3John
   */
  final normalized = canonicalName.replaceAll(' ', '');

  final romanCandidates = romanToArabicBookName(canonicalName);

  final candidates = <String>[
    ...exactCandidates,
    normalized,
    ...romanCandidates,
  ];

  /*
   * Remove duplicates while preserving order.
   */
  final uniqueCandidates = <String>[];

  for (final candidate in candidates) {
    if (!uniqueCandidates.contains(candidate)) {
      uniqueCandidates.add(candidate);
    }
  }

  for (final candidate in uniqueCandidates) {
    final url = '$baseUrl/$candidate.json';

    if (await urlExists(client, url)) {
      return candidate;
    }
  }

  throw FormatException(
    'Could not find a me_bible source file '
    'for AKJV book "$canonicalName".\n'
    'Tried:\n'
    '${uniqueCandidates.map((value) => '  - $value.json').join('\n')}',
  );
}

List<String> romanToArabicBookName(String name) {
  final mappings = <String, String>{
    'I Samuel': '1Samuel',
    'II Samuel': '2Samuel',
    'I Kings': '1Kings',
    'II Kings': '2Kings',
    'I Chronicles': '1Chronicles',
    'II Chronicles': '2Chronicles',
    'I Corinthians': '1Corinthians',
    'II Corinthians': '2Corinthians',
    'I Thessalonians': '1Thessalonians',
    'II Thessalonians': '2Thessalonians',
    'I Timothy': '1Timothy',
    'II Timothy': '2Timothy',
    'I Peter': '1Peter',
    'II Peter': '2Peter',
    'I John': '1John',
    'II John': '2John',
    'III John': '3John',

    // AKJV canonical name → me_bible filename
    'Revelation of John': 'Revelation',
  };

  final result = mappings[name];

  if (result == null) {
    return const [];
  }

  return [result];
}

Future<bool> urlExists(HttpClient client, String url) async {
  final uri = Uri.parse(url);

  try {
    final request = await client.headUrl(uri);

    final response = await request.close();

    await response.drain();

    return response.statusCode == 200;
  } catch (_) {
    return false;
  }
}

Future<dynamic> downloadJson(HttpClient client, String url) async {
  final uri = Uri.parse(url);

  final request = await client.getUrl(uri);

  request.headers.set(HttpHeaders.acceptHeader, 'application/json');

  final response = await request.close();

  final body = await utf8.decoder.bind(response).join();

  if (response.statusCode != 200) {
    throw HttpException(
      'GitHub returned HTTP '
      '${response.statusCode} for $url\n'
      'Response: $body',
      uri: uri,
    );
  }

  try {
    return jsonDecode(body);
  } on FormatException catch (error) {
    throw FormatException(
      'Invalid JSON downloaded from $url: '
      '${error.message}',
    );
  }
}

Map<String, dynamic> convertBook(dynamic source, String canonicalBookName) {
  if (source is! Map) {
    throw FormatException(
      '$canonicalBookName source must contain '
      'a JSON object.',
    );
  }

  final sourceChapters = source['chapters'];

  if (sourceChapters is! List) {
    throw FormatException(
      '$canonicalBookName is missing '
      '"chapters".',
    );
  }

  final chapters = <Map<String, dynamic>>[];

  var expectedChapter = 1;

  for (final sourceChapter in sourceChapters) {
    if (sourceChapter is! Map) {
      throw FormatException(
        'Invalid chapter in '
        '$canonicalBookName.',
      );
    }

    final chapter = int.tryParse(sourceChapter['chapter']?.toString() ?? '');

    if (chapter == null) {
      throw FormatException(
        'Invalid chapter number in '
        '$canonicalBookName.',
      );
    }

    if (chapter != expectedChapter) {
      throw FormatException(
        'Unexpected chapter number in '
        '$canonicalBookName.\n'
        'Expected: $expectedChapter\n'
        'Found:    $chapter',
      );
    }

    final sourceVerses = sourceChapter['verses'];

    if (sourceVerses is! List) {
      throw FormatException(
        '$canonicalBookName $chapter '
        'is missing "verses".',
      );
    }

    final verses = <Map<String, dynamic>>[];

    var expectedVerse = 1;

    for (final sourceVerse in sourceVerses) {
      if (sourceVerse is! Map) {
        throw FormatException(
          'Invalid verse in '
          '$canonicalBookName $chapter.',
        );
      }

      final verse = int.tryParse(sourceVerse['verse']?.toString() ?? '');

      if (verse == null) {
        throw FormatException(
          'Invalid verse number in '
          '$canonicalBookName $chapter.',
        );
      }

      if (verse != expectedVerse) {
        throw FormatException(
          'Unexpected verse number in '
          '$canonicalBookName $chapter.\n'
          'Expected: $expectedVerse\n'
          'Found:    $verse',
        );
      }

      final text = sourceVerse['text'];

      if (text is! String) {
        throw FormatException(
          'Missing text for '
          '$canonicalBookName '
          '$chapter:$verse.',
        );
      }

      verses.add({
        'verse': verse,
        'chapter': chapter,
        'name':
            '$canonicalBookName '
            '$chapter:$verse',
        'text': text,
      });

      expectedVerse++;
    }

    chapters.add({
      'chapter': chapter,
      'name': '$canonicalBookName $chapter',
      'verses': verses,
    });

    expectedChapter++;
  }

  return {'name': canonicalBookName, 'chapters': chapters};
}

void verifyBookNames(
  List<dynamic> akjvBooks,
  List<Map<String, dynamic>> outputBooks,
) {
  if (akjvBooks.length != outputBooks.length) {
    throw FormatException(
      'Book count mismatch.\n'
      'AKJV: ${akjvBooks.length}\n'
      'KJV-edit: ${outputBooks.length}',
    );
  }

  for (var i = 0; i < akjvBooks.length; i++) {
    final akjvBook = akjvBooks[i];

    final outputBook = outputBooks[i];

    if (akjvBook is! Map) {
      throw FormatException('Invalid AKJV book at index $i.');
    }

    final expected = akjvBook['name']?.toString();

    final actual = outputBook['name']?.toString();

    if (expected != actual) {
      throw FormatException(
        'Book-name mismatch at index $i.\n'
        'AKJV.json:     "$expected"\n'
        'KJV-edit.json: "$actual"',
      );
    }
  }
}
