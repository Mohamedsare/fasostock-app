import 'package:supabase_flutter/supabase_flutter.dart';

/// Notification in-app (table notifications).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.createdAt,
    this.body,
    this.readAt,
    this.companyId,
  });

  final String id;
  final String type;
  final String title;
  final String? body;
  final DateTime createdAt;
  final DateTime? readAt;
  final String? companyId;

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final created = json['created_at'];
    final read = json['read_at'];
    return AppNotification(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String?,
      createdAt: created is String ? DateTime.parse(created) : created as DateTime,
      readAt: read != null ? (read is String ? DateTime.parse(read) : read as DateTime) : null,
      companyId: json['company_id'] as String?,
    );
  }
}

class NotificationsRepository {
  NotificationsRepository([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  Future<List<AppNotification>> list({int limit = 50}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    final data = await _client
        .from('notifications')
        .select('id, type, title, body, read_at, company_id, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (data as List).map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<int> unreadCount() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return 0;
    final list = await _client
        .from('notifications')
        .select('id, read_at')
        .eq('user_id', uid)
        .isFilter('read_at', null)
        .limit(500);
    return (list as List).length;
  }

  Future<void> markRead(String id) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _client.from('notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id).eq('user_id', uid);
  }

  Future<void> markAllRead() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _client.from('notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('user_id', uid).isFilter('read_at', null);
  }
}
