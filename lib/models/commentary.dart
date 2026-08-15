class Highlight {
  final String text;
  final String color;

  const Highlight({
    required this.text,
    required this.color,
  });

  factory Highlight.fromJson(Map<String, dynamic> json) {
    return Highlight(
      text: json['text']?.toString() ?? '',
      color: json['color']?.toString() ?? 'yellow',
    );
  }
}

class HashTag {
  final String text;
  final String color;

  const HashTag({
    required this.text,
    required this.color,
  });

  factory HashTag.fromJson(Map<String, dynamic> json) {
    return HashTag(
      text: json['text']?.toString() ?? '',
      color: json['color']?.toString() ?? 'green',
    );
  }
}

class Commentary {
  final int chapter;
  final int verse;
  final String text;
  final List<Highlight> highlights;
  final List<HashTag> hashtags;

  const Commentary({
    required this.chapter,
    required this.verse,
    required this.text,
    this.highlights = const [],
    this.hashtags = const [],
  });

  factory Commentary.fromJson(Map<String, dynamic> json) {
    final rawHighlights = json['highlights'];
    final rawHashtags = json['hashtags'];

    return Commentary(
      chapter: (json['chapter'] as num?)?.toInt() ?? 0,
      verse: (json['verse'] as num?)?.toInt() ?? 0,
      text: json['text']?.toString() ?? '',
      highlights: rawHighlights is List
          ? rawHighlights
              .whereType<Map>()
              .map(
                (item) => Highlight.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where(
                (highlight) => highlight.text.trim().isNotEmpty,
              )
              .toList()
          : const [],
      hashtags: rawHashtags is List
          ? rawHashtags
              .whereType<Map>()
              .map(
                (item) => HashTag.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where(
                (tag) => tag.text.trim().isNotEmpty,
              )
              .toList()
          : const [],
    );
  }
}
