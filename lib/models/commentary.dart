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

class Tag {
  final String text;
  final String color;

  const Tag({
    required this.text,
    this.color = 'yellow',
  });

  factory Tag.fromJson(dynamic json) {
    /*
     * Support:
     *
     * "tags": [
     *   "unicorn"
     * ]
     *
     * and:
     *
     * "tags": [
     *   {
     *     "text": "unicorn"
     *   }
     * ]
     *
     * and:
     *
     * "tags": [
     *   {
     *     "text": "unicorn",
     *     "color": "yellow"
     *   }
     * ]
     */

    if (json is String) {
      return Tag(
        text: json,
      );
    }

    if (json is Map) {
      final map = Map<String, dynamic>.from(json);

      return Tag(
        text: map['text']?.toString() ?? '',
        color: map['color']?.toString() ?? 'yellow',
      );
    }

    return const Tag(
      text: '',
    );
  }
}

class Commentary {
  final int chapter;
  final int verse;
  final String text;

  final List<Highlight> highlights;
  final List<HashTag> hashtags;
  final List<Tag> tags;

  const Commentary({
    required this.chapter,
    required this.verse,
    required this.text,
    this.highlights = const [],
    this.hashtags = const [],
    this.tags = const [],
  });

  factory Commentary.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawHighlights = json['highlights'];

    final rawHashtags = json['hashtags'];

    final rawTags = json['tags'];

    return Commentary(
      chapter:
          (json['chapter'] as num?)?.toInt() ?? 0,

      verse:
          (json['verse'] as num?)?.toInt() ?? 0,

      text:
          json['text']?.toString() ?? '',

      highlights: rawHighlights is List
          ? rawHighlights
              .whereType<Map>()
              .map(
                (item) => Highlight.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where(
                (highlight) =>
                    highlight.text.trim().isNotEmpty,
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
                (hashtag) =>
                    hashtag.text.trim().isNotEmpty,
              )
              .toList()
          : const [],

      tags: rawTags is List
          ? rawTags
              .map(Tag.fromJson)
              .where(
                (tag) =>
                    tag.text.trim().isNotEmpty,
              )
              .toList()
          : const [],
    );
  }
}
