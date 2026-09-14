import 'package:flutter_test/flutter_test.dart';
import 'package:mesee/post_repository.dart';

void main() {
  test('PostRecord maps server counters and media fields', () {
    final post = PostRecord.fromMap({
      'id': 'post-1',
      'author_id': 'user-1',
      'author_handle': 'creator',
      'caption': 'hello',
      'media_type': 'video_vertical',
      'view_count': 12,
      'like_count': 4,
      'media_url': 'https://cdn.example/video.mp4',
    });
    expect(post.authorHandle, 'creator');
    expect(post.viewCount, 12);
    expect(post.likeCount, 4);
    expect(post.mediaUrl, contains('video.mp4'));
  });

  test('development feed falls back without Supabase configuration', () async {
    final posts = await const PostRepository().fetchRecommended();
    expect(posts, isNotEmpty);
    expect(posts.every((post) => post.id.startsWith('local-')), isTrue);
  });

  test('PostRecord maps profile post title/body schema', () {
    final post = PostRecord.fromMap({
      'id': 'post-2',
      'author_id': 'user-1',
      'title': 'タイトル',
      'body': '本文',
      'kind': 'text',
      'view_count': 0,
      'like_count': 0,
    });
    expect(post.caption, '本文');
    expect(post.mediaType, 'text');
  });
}
