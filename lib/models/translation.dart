class BibleTranslation {
  final String id;
  final String name;
  final String file;
  final bool canBePrimary;

  const BibleTranslation({
    required this.id,
    required this.name,
    required this.file,
    required this.canBePrimary,
  });

  factory BibleTranslation.fromJson(
    Map<String, dynamic> json,
  ) {
    return BibleTranslation(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      file: json['file']?.toString() ?? '',
      canBePrimary: json['canBePrimary'] == true,
    );
  }

  @override
  String toString() => '$id - $name';
}
