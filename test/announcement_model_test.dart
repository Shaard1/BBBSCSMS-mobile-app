import 'package:capstone_app/models/announcement_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extracts and de-duplicates announcement image URLs', () {
    final announcement = Announcement.fromJson({
      'id': 'announcement-1',
      'title': 'Road closure',
      'content': 'Use the alternate route.',
      'thumbnail_url': 'https://cdn.example/thumb.jpg',
      'image_urls': [
        'https://cdn.example/road.jpg',
        'https://cdn.example/road.jpg',
      ],
      'created_at': '2026-09-21T08:00:00Z',
    });

    expect(announcement.thumbnailUrl, 'https://cdn.example/thumb.jpg');
    expect(announcement.imageUrls, [
      'https://cdn.example/thumb.jpg',
      'https://cdn.example/road.jpg',
    ]);
    expect(announcement.createdAt, DateTime.parse('2026-09-21T08:00:00Z'));
  });

  test('converts Quill delta JSON into plain text', () {
    final announcement = Announcement.fromJson({
      'content': '[{"insert":"Stay safe during the storm.\\n"}]',
    });

    expect(announcement.plainText, 'Stay safe during the storm.');
  });

  test('uses safe defaults for missing and malformed fields', () {
    final announcement = Announcement.fromJson({
      'image_urls': '[not valid json]',
      'content': '[align=center][b]Notice[/b][/align]',
    });

    expect(announcement.isPublished, isTrue);
    expect(announcement.imageUrls, ['[not valid json]']);
    expect(announcement.plainText, 'Notice');
  });
}
