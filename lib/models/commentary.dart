class Highlight {
  final String text;
  final String color;

  Highlight({required this.text, required this.color});

  factory Highlight.fromJson(Map<String, dynamic> json) {
    return Highlight(
      text: json['text'] as String? ?? '',
      color: json['color'] as String? ?? 'yellow',
    );
  }
}

class HashTag {
  final String text;
  final String color;

  HashTag({required this.text, required this.color});

  factory HashTag.fromJson(Map<String, dynamic> json) {
    return HashTag(
      text: json['text'] as String? ?? '',
      color: json['color'] as String? ?? 'green',
    );
  }
}

class Commentary {
  final int chapter;
  final int verse;
  final String text;
  final List<Highlight> highlights;
  final List<HashTag> hashtags;

  Commentary({
    required this.chapter,
    required this.verse,
    required this.text,
    this.highlights = const [],
    this.hashtags = const [],
  });

  factory Commentary.fromJson(Map<String, dynamic> json) {
    return Commentary(
      chapter: (json['chapter'] as num).toInt(),
      verse: (json['verse'] as num).toInt(),
      text: json['text'] as String? ?? '',
      highlights: (json['highlights'] as List? ?? [])
          .map((e) => Highlight.fromJson(e as Map<String, dynamic>))
          .toList(),
      hashtags: (json['hashtags'] as List? ?? [])
          .map((e) => HashTag.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
