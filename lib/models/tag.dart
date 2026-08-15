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

  /*
   * All possible forms of this tag that should be
   * searched for in a verse.
   *
   * Example:
   *
   * phrase:
   *   "fowl"
   *
   * variants:
   *   ["Fowl", "Fowls"]
   *
   * searchTerms:
   *   ["fowl", "Fowl", "Fowls"]
   */
  List<String> get searchTerms {
    final result = <String>[];

    final mainPhrase = phrase.trim();

    if (mainPhrase.isNotEmpty) {
      result.add(mainPhrase);
    }

    for (final variant in variants) {
      final value = variant.trim();

      if (value.isEmpty) {
        continue;
      }

      if (!result.contains(value)) {
        result.add(value);
      }
    }

    return result;
  }

  @override
  String toString() {
    return 'BibleTag('
        'name: $name, '
        'phrase: $phrase, '
        'variants: $variants'
        ')';
  }
}
