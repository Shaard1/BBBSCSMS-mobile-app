import 'dart:convert';

class Announcement {
  final String id;
  final String title;
  final String content;
  final bool isPublished;
  final String thumbnailUrl;
  final List<String> imageUrls;
  final DateTime createdAt;

  Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.isPublished,
    required this.thumbnailUrl,
    required this.imageUrls,
    required this.createdAt,
  });

  String get plainText {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return '';

    if (trimmed.startsWith('[')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          final buffer = StringBuffer();
          for (final operation in decoded) {
            if (operation is Map && operation['insert'] is String) {
              buffer.write(operation['insert'] as String);
            }
          }
          final extracted = buffer.toString().trim();
          if (extracted.isNotEmpty) {
            return extracted;
          }
        }
      } catch (_) {}
    }

    return trimmed
        .replaceAll(
          RegExp(r'\[align=(left|center|right|justify)\]|\[/align\]', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\[size=\d+\]|\[/size\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[/?[bius]\]', caseSensitive: false), '')
        .trim();
  }

  static List<String> _extractImageUrls(Map<String, dynamic> json) {
    final urls = <String>[];

    void addUrl(dynamic value) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        urls.add(text);
      }
    }

    addUrl(json['thumbnail_url']);

    final raw = json['image_urls'];
    if (raw is List) {
      for (final item in raw) {
        addUrl(item);
      }
    } else if (raw is String) {
      final text = raw.trim();
      if (text.startsWith('[') && text.endsWith(']')) {
        try {
          final decoded = jsonDecode(text);
          if (decoded is List) {
            for (final item in decoded) {
              addUrl(item);
            }
          }
        } catch (_) {
          addUrl(raw);
        }
      } else {
        addUrl(raw);
      }
    }

    return urls.toSet().toList();
  }

  factory Announcement.fromJson(Map<String, dynamic> json) {
    final imageUrls = _extractImageUrls(json);
    final thumbnailUrl =
        (json['thumbnail_url']?.toString().trim().isNotEmpty ?? false)
            ? json['thumbnail_url'].toString()
            : (imageUrls.isNotEmpty ? imageUrls.first : '');

    return Announcement(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      isPublished: json['is_published'] == null ? true : json['is_published'] == true,
      thumbnailUrl: thumbnailUrl,
      imageUrls: imageUrls,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
