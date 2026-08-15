enum BibleReferenceType {
  verse,
  verseRange,
  chapter,
}

class BibleReference {
  final String book;
  final int chapter;
  final int? startVerse;
  final int? endVerse;
  final String translation;

  const BibleReference({
    required this.book,
    required this.chapter,
    required this.startVerse,
    required this.endVerse,
    required this.translation,
  });

  BibleReferenceType get type {
    if (startVerse == null) {
      return BibleReferenceType.chapter;
    }

    if (endVerse != null && endVerse != startVerse) {
      return BibleReferenceType.verseRange;
    }

    return BibleReferenceType.verse;
  }

  bool get isChapter => type == BibleReferenceType.chapter;

  bool get isSingleVerse => type == BibleReferenceType.verse;

  bool get isRange => type == BibleReferenceType.verseRange;

  String get displayReference {
    if (isChapter) {
      return '$book $chapter';
    }

    if (isSingleVerse) {
      return '$book $chapter:$startVerse';
    }

    return '$book $chapter:$startVerse-$endVerse';
  }

  BibleReference copyWith({
    String? book,
    int? chapter,
    int? startVerse,
    int? endVerse,
    String? translation,
  }) {
    return BibleReference(
      book: book ?? this.book,
      chapter: chapter ?? this.chapter,
      startVerse: startVerse ?? this.startVerse,
      endVerse: endVerse ?? this.endVerse,
      translation: translation ?? this.translation,
    );
  }
}
