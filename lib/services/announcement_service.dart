import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/announcement_model.dart';

class AnnouncementService {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<List<Announcement>> fetchPublishedAnnouncements() async {
    final response = await supabase
        .from('announcements')
        .select()
        .eq('is_published', true)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Announcement.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  Future<Set<String>> fetchReadAnnouncementIds(String userId) async {
    final response = await supabase
        .from('announcement_reads')
        .select('announcement_id')
        .eq('user_id', userId);

    return (response as List)
        .map((row) => row['announcement_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<Map<String, String>> fetchAuthorNamesByIds(List<String> userIds) async {
    final uniqueIds = userIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (uniqueIds.isEmpty) return {};

    final response = await supabase
        .from('profiles')
        .select('id, full_name')
        .inFilter('id', uniqueIds);

    final result = <String, String>{};
    for (final row in (response as List)) {
      final id = row['id']?.toString() ?? '';
      final fullName = row['full_name']?.toString().trim() ?? '';
      if (id.isNotEmpty && fullName.isNotEmpty) {
        result[id] = fullName;
      }
    }
    return result;
  }

  Future<void> markAnnouncementsRead({
    required String userId,
    required List<String> announcementIds,
  }) async {
    final rows = announcementIds
        .where((id) => id.trim().isNotEmpty)
        .map(
          (id) => {
            'user_id': userId,
            'announcement_id': id,
            'read_at': DateTime.now().toIso8601String(),
          },
        )
        .toList();

    if (rows.isEmpty) return;

    await supabase.from('announcement_reads').upsert(
          rows,
          onConflict: 'user_id,announcement_id',
        );
  }
}
