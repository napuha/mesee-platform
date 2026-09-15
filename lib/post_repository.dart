import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

import 'app_config.dart';

class PostRecord {
  const PostRecord({
    required this.id,
    required this.authorId,
    required this.authorHandle,
    required this.caption,
    required this.mediaType,
    required this.viewCount,
    required this.likeCount,
    this.mediaUrl,
  });

  final String id;
  final String authorId;
  final String authorHandle;
  final String caption;
  final String mediaType;
  final int viewCount;
  final int likeCount;
  final String? mediaUrl;

  factory PostRecord.fromMap(Map<String, dynamic> map) => PostRecord(
        id: map['id'] as String,
        authorId: map['author_id'] as String? ?? '',
        authorHandle: (map['author_handle'] as String?) ?? '@creator',
        caption: (map['caption'] as String?) ?? (map['body'] as String?) ?? (map['title'] as String?) ?? '',
        mediaType: (map['media_type'] as String?) ?? ((map['kind'] as String?) == 'text' ? 'text' : ((map['kind'] as String?) ?? 'video_vertical')),
        viewCount: (map['view_count'] as num?)?.toInt() ?? 0,
        likeCount: (map['like_count'] as num?)?.toInt() ?? 0,
        mediaUrl: map['media_url'] as String?,
      );

  PostRecord copyWith({String? mediaUrl}) => PostRecord(
        id: id, authorId: authorId, authorHandle: authorHandle, caption: caption, mediaType: mediaType,
        viewCount: viewCount, likeCount: likeCount, mediaUrl: mediaUrl ?? this.mediaUrl,
      );
}

class PostRepository {
  const PostRepository();

  static const _fallback = <PostRecord>[
    PostRecord(id: 'local-1', authorId: '', authorHandle: '@mesee_creator', caption: '夜の街に溶け込むネオン。', mediaType: 'video_vertical', viewCount: 158000, likeCount: 27000),
    PostRecord(id: 'local-2', authorId: '', authorHandle: '@sora.movie', caption: '週末の風景をシェア。', mediaType: 'video_vertical', viewCount: 61000, likeCount: 8200),
    PostRecord(id: 'local-3', authorId: '', authorHandle: '@mika.food', caption: 'お気に入りの味。', mediaType: 'video_horizontal', viewCount: 39900, likeCount: 4300),
  ];

  Future<List<PostRecord>> fetchRecommended() async {
    if (!AppConfig.hasSupabaseConfig) return _fallback;
    try {
      final rows = await Supabase.instance.client.rpc('get_recommended_posts', params: {'result_limit': 20});
      final posts = (rows as List).map((row) => PostRecord.fromMap(Map<String, dynamic>.from(row as Map))).toList();
      return await Future.wait(posts.map((post) async {
        final path = post.mediaUrl;
        if (path == null || path.startsWith('http')) return post;
        try {
          final signed = await Supabase.instance.client.storage.from('mesee-media').createSignedUrl(path, 3600);
          return post.copyWith(mediaUrl: signed);
        } catch (_) {
          return post.copyWith(mediaUrl: null);
        }
      }));
    } catch (_) {
      return _fallback;
    }
  }

  Future<Map<String, dynamic>?> fetchCurrentProfile() async {
    if (!AppConfig.hasSupabaseConfig) return null;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;
    final profile = await Supabase.instance.client.from('profiles').select('display_name,username,bio,is_private,avatar_url,header_url').eq('id', userId).maybeSingle();
    if (profile == null) return null;
    for (final key in ['avatar_url', 'header_url']) {
      final path = profile[key] as String?;
      if (path != null && path.isNotEmpty && !path.startsWith('http')) {
        try { profile[key] = await Supabase.instance.client.storage.from('mesee-media').createSignedUrl(path, 3600); } catch (_) { profile[key] = null; }
      }
    }
    return profile;
  }

  Future<Map<String, dynamic>?> fetchProfileStats() async {
    if (!AppConfig.hasSupabaseConfig || Supabase.instance.client.auth.currentUser == null) return null;
    final result = await Supabase.instance.client.rpc('get_profile_stats');
    return result is Map ? Map<String, dynamic>.from(result) : null;
  }

  Future<List<PostRecord>> fetchOwnPosts({String? kind, bool popular = false}) async {
    if (!AppConfig.hasSupabaseConfig) return const <PostRecord>[];
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return const <PostRecord>[];
    var query = Supabase.instance.client.from('posts').select('id,author_id,title,body,kind,view_count,like_count,media_url').eq('author_id', userId).neq('status', 'deleted');
    if (kind != null) query = query.eq('kind', kind);
    final rows = popular
        ? await query.order('like_count', ascending: false).order('view_count', ascending: false).order('published_at', ascending: false).limit(60)
        : await query.order('published_at', ascending: false).limit(60);
    return _resolveMedia((rows as List).map((row) => PostRecord.fromMap(Map<String, dynamic>.from(row as Map))).toList());
  }

  Future<List<PostRecord>> fetchReactionPosts(String reaction) async {
    if (!AppConfig.hasSupabaseConfig) return const <PostRecord>[];
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return const <PostRecord>[];
    final rows = await Supabase.instance.client.from('post_reactions').select('posts(id,author_id,title,body,kind,view_count,like_count,media_url)').eq('user_id', userId).eq('reaction', reaction);
    final posts = (rows as List).where((row) => row['posts'] != null).map((row) => PostRecord.fromMap(Map<String, dynamic>.from(row['posts'] as Map))).toList();
    return _resolveMedia(posts);
  }

  Future<List<PostRecord>> _resolveMedia(List<PostRecord> posts) async {
    return Future.wait(posts.map((post) async {
      final path = post.mediaUrl;
      if (path == null || path.startsWith('http')) return post;
      try {
        final signed = await Supabase.instance.client.storage.from('mesee-media').createSignedUrl(path, 3600);
        return post.copyWith(mediaUrl: signed);
      } catch (_) {
        return post.copyWith(mediaUrl: null);
      }
    }));
  }

  Future<void> recordView(String postId) async {
    if (!AppConfig.hasSupabaseConfig || postId.startsWith('local-')) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    await Supabase.instance.client.from('post_view_events').insert({
      'post_id': postId,
      'viewer_id': userId,
      'event_type': 'view_complete',
    });
  }

  Future<void> recordImpression(String postId) async {
    if (!AppConfig.hasSupabaseConfig || postId.startsWith('local-')) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try { await Supabase.instance.client.from('post_view_events').insert({'post_id': postId, 'viewer_id': userId, 'event_type': 'impression'}); } catch (_) { }
  }

  Future<Map<String, dynamic>?> fetchCreatorAnalytics() async {
    if (!AppConfig.hasSupabaseConfig) return null;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;
    final result = await Supabase.instance.client.rpc('get_creator_analytics', params: {'target_creator': userId});
    return result is Map ? Map<String, dynamic>.from(result) : null;
  }

  Future<Map<String, dynamic>?> fetchUserSettings() async {
    if (!AppConfig.hasSupabaseConfig) return null;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;
    return Supabase.instance.client.from('user_settings').select('notify_likes,notify_saves,notify_followers,notify_reposts,notify_messages').eq('user_id', userId).maybeSingle();
  }

  Future<void> updateUserSettings(Map<String, bool> values) async {
    if (!AppConfig.hasSupabaseConfig) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw const AuthException('ログインが必要です。');
    await Supabase.instance.client.from('user_settings').upsert({...values, 'user_id': userId});
  }

  Future<Map<String, dynamic>?> requestAccountDeletion() async {
    if (!AppConfig.hasSupabaseConfig) return null;
    final result = await Supabase.instance.client.rpc('request_account_deletion');
    return result is Map ? Map<String, dynamic>.from(result) : null;
  }

  Future<Map<String, dynamic>?> cancelAccountDeletion() async {
    if (!AppConfig.hasSupabaseConfig) return null;
    final result = await Supabase.instance.client.rpc('cancel_account_deletion');
    return result is Map ? Map<String, dynamic>.from(result) : null;
  }

  Future<void> toggleReaction(String postId, String reaction, bool enabled) async {
    if (!AppConfig.hasSupabaseConfig || postId.startsWith('local-')) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final table = Supabase.instance.client.from('post_reactions');
    if (enabled) {
      await table.upsert({'post_id': postId, 'user_id': userId, 'reaction': reaction});
    } else {
      await table.delete().eq('post_id', postId).eq('user_id', userId).eq('reaction', reaction);
    }
  }

  Future<void> toggleFollow(String authorId, bool following) async {
    if (!AppConfig.hasSupabaseConfig) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || authorId.isEmpty || userId == authorId) return;
    final table = Supabase.instance.client.from('follows');
    if (following) {
      await table.upsert({'follower_id': userId, 'following_id': authorId});
    } else {
      await table.delete().eq('follower_id', userId).eq('following_id', authorId);
    }
  }

  Future<void> blockUser(String blockedId) async {
    if (!AppConfig.hasSupabaseConfig) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw const AuthException('ログインが必要です。');
    if (blockedId.isEmpty || blockedId == userId) return;
    await Supabase.instance.client.from('blocked_users').upsert({'blocker_id': userId, 'blocked_id': blockedId});
  }

  Future<void> deleteOwnPost(String postId) async {
    if (!AppConfig.hasSupabaseConfig) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw const AuthException('ログインが必要です。');
    await Supabase.instance.client.from('posts').update({'status': 'deleted', 'deleted_at': DateTime.now().toUtc().toIso8601String(), 'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('id', postId).eq('author_id', userId);
  }

  Future<void> reportPost(String postId, String reason) async {
    if (!AppConfig.hasSupabaseConfig) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw const AuthException('ログインが必要です。');
    await Supabase.instance.client.from('reports').insert({'reporter_id': userId, 'post_id': postId, 'reason': reason.trim()});
  }

  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    if (!AppConfig.hasSupabaseConfig) return const <Map<String, dynamic>>[];
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return const <Map<String, dynamic>>[];
    final rows = await Supabase.instance.client.from('notifications').select('id,kind,created_at,read_at,profiles!notifications_actor_id_fkey(username)').eq('user_id', userId).order('created_at', ascending: false).limit(50);
    return (rows as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<void> markNotificationsRead() async {
    if (!AppConfig.hasSupabaseConfig) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    await Supabase.instance.client.from('notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('user_id', userId).isFilter('read_at', null);
  }

  Future<List<Map<String, dynamic>>> fetchMessages() async {
    if (!AppConfig.hasSupabaseConfig) return const <Map<String, dynamic>>[];
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return const <Map<String, dynamic>>[];
    final rows = await Supabase.instance.client.from('messages').select('id,body,created_at,sender_id,recipient_id').or('sender_id.eq.$userId,recipient_id.eq.$userId').order('created_at', ascending: false).limit(50);
    return (rows as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<void> sendMessage({required String username, required String body}) async {
    if (!AppConfig.hasSupabaseConfig) throw const AuthException('Supabase接続が必要です。');
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw const AuthException('ログインが必要です。');
    final normalized = username.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase();
    final profile = await Supabase.instance.client.from('profiles').select('id').eq('username', normalized).maybeSingle();
    final recipientId = profile?['id'] as String?;
    if (recipientId == null || recipientId == userId) throw const PostgrestException(message: '送信先ユーザーが見つかりません。');
    await Supabase.instance.client.from('messages').insert({'sender_id': userId, 'recipient_id': recipientId, 'body': body.trim()});
  }

  Stream<List<Map<String, dynamic>>> liveComments(String livePostId) {
    if (!AppConfig.hasSupabaseConfig) return const Stream.empty();
    return Supabase.instance.client.from('live_comments').stream(primaryKey: ['id']).eq('live_post_id', livePostId).order('created_at', ascending: true);
  }

  Future<void> sendLiveComment({required String livePostId, required String body}) async {
    if (!AppConfig.hasSupabaseConfig) throw const AuthException('Supabase接続が必要です。');
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final trimmed = body.trim();
    if (userId == null) throw const AuthException('ログインが必要です。');
    if (trimmed.isEmpty || trimmed.length > 500) throw const PostgrestException(message: 'コメントは1〜500文字で入力してください。');
    await Supabase.instance.client.from('live_comments').insert({'live_post_id': livePostId, 'author_id': userId, 'body': trimmed});
  }

  Future<String?> createTextPost({required String title, required String body, String visibility = 'public'}) async {
    if (!AppConfig.hasSupabaseConfig) return null;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw const AuthException('ログインが必要です。');
    final row = await Supabase.instance.client.from('posts').insert({
      'author_id': userId,
      'kind': 'text',
      'title': title.trim(),
      'body': body.trim(),
      'visibility': visibility,
      'status': 'ready',
      'published_at': DateTime.now().toUtc().toIso8601String(),
    }).select('id').single();
    return row['id'] as String;
  }

  Future<String?> createLivePost({required String title, required String description, required String visibility}) async {
    if (!AppConfig.hasSupabaseConfig) return null;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw const AuthException('ログインが必要です。');
    final row = await Supabase.instance.client.from('posts').insert({'author_id': userId, 'kind': 'live', 'title': title.trim(), 'body': description.trim(), 'visibility': visibility, 'status': 'draft'}).select('id').single();
    return row['id'] as String;
  }

  Future<void> updateProfile({required String displayName, required String username, required String bio, bool isPrivate = false, XFile? avatar, XFile? header}) async {
    if (!AppConfig.hasSupabaseConfig) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw const AuthException('ログインが必要です。');
    final normalized = username.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase();
    if (normalized.isEmpty) throw const PostgrestException(message: 'ユーザーネームを入力してください。');
    final updates = <String, dynamic>{
      'display_name': displayName.trim(),
      'username': normalized,
      'bio': bio.trim(),
      'is_private': isPrivate,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    for (final entry in {'avatar_url': avatar, 'header_url': header}.entries) {
      final file = entry.value;
      if (file == null) continue;
      final mime = file.mimeType ?? '';
      final isImage = mime.startsWith('image/') || RegExp(r'\.(png|jpe?g|webp|heic)$', caseSensitive: false).hasMatch(file.name);
      if (!isImage) throw const PostgrestException(message: 'プロフィール画像は画像ファイルを選択してください。');
      final path = '$userId/profile_${entry.key}_${DateTime.now().microsecondsSinceEpoch}';
      await Supabase.instance.client.storage.from('mesee-media').uploadBinary(path, await file.readAsBytes(), fileOptions: const FileOptions(upsert: false));
      updates[entry.key] = path;
    }
    await Supabase.instance.client.from('profiles').update(updates).eq('id', userId);
  }

  Future<String> createMediaPost({required XFile file, required String kind, required String title, String visibility = 'public'}) async {
    if (!AppConfig.hasSupabaseConfig) throw const AuthException('Supabase接続が必要です。');
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw const AuthException('ログインが必要です。');
    final size = await file.length();
    if (size > 500 * 1024 * 1024) throw const PostgrestException(message: 'ファイルサイズは500MB以下にしてください。');
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw const PostgrestException(message: 'ファイルを読み込めませんでした。');
    final extension = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'bin';
    final path = '$userId/${DateTime.now().microsecondsSinceEpoch}.$extension';
    await Supabase.instance.client.storage.from('mesee-media').uploadBinary(path, bytes, fileOptions: FileOptions(upsert: false));
    try {
      final row = await Supabase.instance.client.from('posts').insert({
        'author_id': userId, 'kind': kind, 'title': title.trim(), 'visibility': visibility,
        'status': 'ready', 'media_url': path, 'published_at': DateTime.now().toUtc().toIso8601String(),
      }).select('id').single();
      return row['id'] as String;
    } catch (_) {
      try { await Supabase.instance.client.storage.from('mesee-media').remove([path]); } catch (_) { }
      rethrow;
    }
  }
}
