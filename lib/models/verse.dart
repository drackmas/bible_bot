class Verse {
  final int chapter;
  final int verse;
  final String text;

  const Verse({
    required this.chapter,
    required this.verse,
    required this.text,
  });

  factory Verse.fromJson(
    Map<String, dynamic> json,
    int chapterNumber,
  ) {
    return Verse(
      chapter: chapterNumber,
      verse: int.parse(json['verse'].toString()),
      text: json['text']?.toString() ?? '',
    );
  }

  String get reference => '$chapter:$verse';

  @override
  String toString() => '$chapter:$verse  $text';
}
