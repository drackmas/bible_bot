class BibleTag {
  final String name;
  final String phrase;
  final List<String> variants;

  const BibleTag({
    required this.name,
    required this.phrase,
    this.variants = const [],
  });

  factory BibleTag.fromJson(
    Map<String, dynamic> json,
  ) {
    return BibleTag(
      name: json['name']?.toString() ?? '',
      phrase: json['phrase']?.toString() ?? '',
      variants: (json['variants'] as List? ?? [])
          .map(
            (value) => value.toString(),
          )
          .where(
            (value) => value.trim().isNotEmpty,
          )
          .toList(),
    );
  }

  /// All strings that should be checked against
  /// the KJV verse.
  List<String> get searchTerms {
    final result = <String>[];

    if (phrase.trim().isNotEmpty) {
      result.add(phrase.trim());
    }

    for (final variant in variants) {
      final value = variant.trim();

      if (value.isNotEmpty &&
          !result.contains(value)) {
        result.add(value);
      }
    }

    return result;
  }

  /// ALL-CAPS tags such as:
  ///
  /// GOD
  /// LORD
  /// JESUS
  ///
  /// are treated as case-sensitive.
  ///
  /// Therefore:
  ///
  /// GOD != God
  /// LORD != Lord
  ///
  /// Normal tags such as "bottles" remain
  /// case-insensitive.
  static bool isCaseSensitive(String value) {
    final letters = value.replaceAll(
      RegExp(r'[^A-Za-z]'),
      '',
    );

    if (letters.isEmpty) {
      return false;
    }

    return letters == letters.toUpperCase() &&
        letters != letters.toLowerCase();
  }
}
