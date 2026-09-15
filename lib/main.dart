// The moderation flow intentionally awaits modal results before showing the next modal.
// Each resulting action is still guarded by `mounted` before UI feedback.
// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'package:flutter/material.dart';
import 'app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'post_repository.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.hasSupabaseConfig) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
  }
  runApp(const MeSeeApp());
}

class MeSeeApp extends StatelessWidget {
  const MeSeeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'MeSee ${AppConfig.environment}',
        theme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: const Color(0xff08080c), colorSchemeSeed: const Color(0xffec4899), useMaterial3: true),
        home: AppConfig.isProduction && !AppConfig.hasSupabaseConfig ? const _ProductionConfigErrorPage() : const AuthGate(),
      );
}

class _ProductionConfigErrorPage extends StatelessWidget {
  const _ProductionConfigErrorPage();
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 56, color: Colors.orange),
                SizedBox(height: 16),
                Text('本番設定が不足しています', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Supabase URLと公開キーを設定してから起動してください。', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    if (!AppConfig.hasSupabaseConfig) return const Shell();
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) => snapshot.data?.session == null ? const AuthPage() : const Shell(),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool isSignUp = false, busy = false;
  String? error;

  Future<void> submit() async {
    setState(() { busy = true; error = null; });
    try {
      final auth = Supabase.instance.client.auth;
      if (isSignUp) {
        await auth.signUp(email: email.text.trim(), password: password.text);
      } else {
        await auth.signInWithPassword(email: email.text.trim(), password: password.text);
      }
    } on AuthException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } catch (_) {
      if (mounted) setState(() => error = '通信に失敗しました。時間を置いて再試行してください。');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() { email.dispose(); password.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Logo(),
                  const SizedBox(height: 28),
                  Text(isSignUp ? 'アカウントを作成' : 'MeSeeにログイン', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'メールアドレス', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'パスワード', border: OutlineInputBorder())),
                  if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.redAccent))),
                  const SizedBox(height: 20),
                  FilledButton(onPressed: busy ? null : submit, child: Text(busy ? '処理中…' : (isSignUp ? '登録する' : 'ログイン'))),
                  TextButton(onPressed: busy ? null : () => setState(() => isSignUp = !isSignUp), child: Text(isSignUp ? 'ログインへ戻る' : '新規登録はこちら')),
                ],
              ),
            ),
          ),
        ),
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  final pages = const [HomePage(), VerticalPage(), HorizontalPage(), MessagesPage(), ProfilePage()];
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: tab == 1 ? null : AppBar(title: const Logo(), actions: [IconButton(onPressed: () => showDialog<void>(context: context, builder: (_) => const _NotificationsDialog()), icon: const Icon(Icons.notifications_none)), IconButton(onPressed: () => showModalBottomSheet(context: context, builder: (_) => const CreateSheet()), icon: const Icon(Icons.add_box_outlined))]),
        body: pages[tab],
        bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (value) => setState(() => tab = value), destinations: const [NavigationDestination(icon: Icon(Icons.home_outlined), label: 'ホーム'), NavigationDestination(icon: Icon(Icons.view_carousel_outlined), label: '縦動画'), NavigationDestination(icon: Icon(Icons.play_circle_outline), label: '横動画'), NavigationDestination(icon: Icon(Icons.mail_outline), label: 'メッセージ'), NavigationDestination(icon: Icon(Icons.person_outline), label: 'プロフィール')]),
      );
}

class Logo extends StatelessWidget { const Logo({super.key}); @override Widget build(BuildContext context) => ShaderMask(shaderCallback: (r) => const LinearGradient(colors: [Color(0xff8b5cf6), Color(0xffec4899), Color(0xffff9f43)]).createShader(r), child: const Text('MS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -5))); }

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) => FutureBuilder<List<PostRecord>>(
        future: const PostRepository().fetchRecommended(),
        builder: (context, snapshot) {
          final posts = snapshot.data ?? const <PostRecord>[];
          if (snapshot.connectionState == ConnectionState.waiting && posts.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError && posts.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('フィードを読み込めませんでした。'), const SizedBox(height: 12), OutlinedButton(onPressed: () => (context as Element).markNeedsBuild(), child: const Text('再試行'))]));
          }
          return ListView(padding: const EdgeInsets.all(16), children: [
            const Text('FOR YOU', style: TextStyle(color: Colors.white54, letterSpacing: 2)),
            const SizedBox(height: 8),
            const Text('あなたのフィード', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 18),
            ...posts.map((post) => AppConfig.hasSupabaseConfig ? VideoCard(post: post) : _FallbackVideoCard(post: post)),
          ]);
        },
      );
}
class _FallbackVideoCard extends StatelessWidget {
  const _FallbackVideoCard({required this.post});
  final PostRecord post;
  @override
  Widget build(BuildContext context) => Card(clipBehavior: Clip.antiAlias, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(height: 300, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xff202d50), Color(0xffa63d91)])), child: const Center(child: Icon(Icons.play_circle_outline, size: 64))), Padding(padding: const EdgeInsets.all(14), child: Text('${post.authorHandle}\n${post.caption}\n▶ ${post.viewCount}  ♥ ${post.likeCount}'))]));
}
class VideoCard extends StatefulWidget {
  const VideoCard({required this.post, super.key});
  final PostRecord post;
  @override State<VideoCard> createState() => _VideoCardState();
}
class _VideoCardState extends State<VideoCard> {
  bool liked = false, saved = false, reposted = false, following = false;
  final repository = const PostRepository();
  @override void initState() { super.initState(); repository.recordImpression(widget.post.id); }
  Future<void> _toggle(String reaction, bool value) async {
    try {
      await repository.toggleReaction(widget.post.id, reaction, value);
    } catch (_) {
      if (mounted) setState(() => _setReaction(reaction, !value));
    }
  }
  void _setReaction(String reaction, bool value) {
    if (reaction == 'like') liked = value;
    if (reaction == 'save') saved = value;
    if (reaction == 'repost') reposted = value;
  }
  Future<void> _moderate() async { final action = await showModalBottomSheet<String>(context: context, builder: (_) => SafeArea(child: Wrap(children: [ListTile(leading: const Icon(Icons.flag_outlined), title: const Text('この投稿を報告'), onTap: () => Navigator.pop(context, 'report')), ListTile(leading: const Icon(Icons.delete_outline), title: const Text('自分の投稿を削除'), onTap: () => Navigator.pop(context, 'delete'))]))); if (action == 'report') { final reason = await showDialog<String>(context: context, builder: (_) => const _ReportDialog()); if (reason != null) { await repository.reportPost(widget.post.id, reason); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('報告を送信しました'))); } } if (action == 'delete' && widget.post.authorId.isNotEmpty) { final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('投稿を削除しますか？'), content: const Text('削除後は公開フィードから見えなくなります。'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('削除'))])); if (ok == true) { await repository.deleteOwnPost(widget.post.id); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('投稿を削除しました'))); } } }
  @override
  Widget build(BuildContext context) => Card(clipBehavior: Clip.antiAlias, child: InkWell(onTap: () => repository.recordView(widget.post.id), onLongPress: _moderate, child: Container(height: 360, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xff202d50), Color(0xffa63d91)])), child: Stack(children: [if (widget.post.authorId.isNotEmpty && widget.post.authorId != Supabase.instance.client.auth.currentUser?.id) Positioned(right: 12, top: 12, child: IconButton(onPressed: () async { try { await repository.blockUser(widget.post.authorId); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ユーザーをブロックしました'))); } catch (exception) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ブロックに失敗しました: $exception'))); } }, icon: const Icon(Icons.block_outlined))), Positioned.fill(child: widget.post.mediaUrl == null ? const Center(child: Icon(Icons.play_circle_outline, size: 64)) : VideoPreview(url: widget.post.mediaUrl!)), Positioned(left: 16, bottom: 16, child: Row(mainAxisSize: MainAxisSize.min, children: [Text('${widget.post.authorHandle}\n${widget.post.caption}\n▶ ${widget.post.viewCount}  ♥ ${widget.post.likeCount}'), if (widget.post.authorId.isNotEmpty) IconButton(onPressed: () async { final next = !following; setState(() => following = next); try { await repository.toggleFollow(widget.post.authorId, next); } catch (_) { if (mounted) setState(() => following = !next); } }, icon: Icon(following ? Icons.person : Icons.person_add_alt_1, color: following ? Colors.cyan : Colors.white))])), Positioned(right: 12, bottom: 12, child: Column(children: [IconButton(onPressed: () { final next = !liked; setState(() => liked = next); _toggle('like', next); }, icon: Icon(Icons.favorite, color: liked ? Colors.pink : Colors.white)), IconButton(onPressed: () { final next = !saved; setState(() => saved = next); _toggle('save', next); }, icon: Icon(Icons.bookmark, color: saved ? Colors.orange : Colors.white)), IconButton(onPressed: () { final next = !reposted; setState(() => reposted = next); _toggle('repost', next); }, icon: Icon(Icons.repeat, color: reposted ? Colors.cyan : Colors.white))]))]))));
}

class VideoPreview extends StatefulWidget {
  const VideoPreview({required this.url, super.key});
  final String url;
  @override State<VideoPreview> createState() => _VideoPreviewState();
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog();
  @override State<_ReportDialog> createState() => _ReportDialogState();
}
class _ReportDialogState extends State<_ReportDialog> {
  final reason = TextEditingController();
  @override void dispose() { reason.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AlertDialog(title: const Text('投稿を報告'), content: TextField(controller: reason, maxLines: 4, decoration: const InputDecoration(hintText: '理由を入力してください')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')), FilledButton(onPressed: () { if (reason.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('報告理由を入力してください。'))); return; } Navigator.pop(context, reason.text.trim()); }, child: const Text('送信'))]);
}
class _VideoPreviewState extends State<VideoPreview> {
  late final VideoPlayerController controller;
  String? error;
  @override void initState() { super.initState(); controller = VideoPlayerController.networkUrl(Uri.parse(widget.url)); controller.initialize().then((_) { controller.setLooping(true); controller.play(); if (mounted) setState(() {}); }).catchError((_) { if (mounted) setState(() => error = '動画を再生できませんでした。'); }); }
  @override void dispose() { controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    if (RegExp(r'\.(png|jpe?g|webp|gif)(\?|$)', caseSensitive: false).hasMatch(widget.url)) {
      return Image.network(widget.url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, size: 64)));
    }
    return error != null ? Center(child: Text(error!)) : controller.value.isInitialized ? GestureDetector(onTap: () => setState(() => controller.value.isPlaying ? controller.pause() : controller.play()), child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: controller.value.size.width, height: controller.value.size.height, child: VideoPlayer(controller)))) : const Center(child: CircularProgressIndicator());
  }
}
class VerticalPage extends StatelessWidget {
  const VerticalPage({super.key});
  @override
  Widget build(BuildContext context) => FutureBuilder<List<PostRecord>>(
        future: const PostRepository().fetchRecommended(),
        builder: (context, snapshot) {
          final posts = (snapshot.data ?? const <PostRecord>[]).where((post) => post.mediaType == 'video_vertical').toList();
          if (snapshot.connectionState == ConnectionState.waiting && posts.isEmpty) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError && posts.isEmpty) return const Center(child: Text('縦動画を読み込めませんでした。'));
          if (posts.isEmpty) return const Center(child: Text('縦動画はまだありません'));
          return PageView.builder(scrollDirection: Axis.vertical, itemCount: posts.length, itemBuilder: (_, index) => _VerticalPost(post: posts[index]));
        },
      );
}

class _VerticalPost extends StatefulWidget {
  const _VerticalPost({required this.post});
  final PostRecord post;
  @override State<_VerticalPost> createState() => _VerticalPostState();
}
class _VerticalPostState extends State<_VerticalPost> {
  bool liked = false, saved = false, reposted = false;
  @override void initState() { super.initState(); const PostRepository().recordImpression(widget.post.id); }
  Future<void> _toggle(String reaction, bool value) async {
    try { await const PostRepository().toggleReaction(widget.post.id, reaction, value); } catch (_) { if (mounted) setState(() { if (reaction == 'like') liked = !value; if (reaction == 'save') saved = !value; if (reaction == 'repost') reposted = !value; }); }
  }
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => const PostRepository().recordView(widget.post.id),
        child: Stack(fit: StackFit.expand, children: [
          widget.post.mediaUrl == null ? const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xff1b3045), Color(0xffd44886)])), child: Center(child: Icon(Icons.play_circle_outline, size: 72, color: Colors.white))) : VideoPreview(url: widget.post.mediaUrl!),
          Positioned(left: 18, bottom: 28, right: 90, child: Text('${widget.post.authorHandle}\n${widget.post.caption}\n▶ ${widget.post.viewCount}  ♥ ${widget.post.likeCount}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, shadows: [Shadow(blurRadius: 8, color: Colors.black)]))),
          Positioned(right: 12, bottom: 100, child: Column(children: [IconButton(onPressed: () { final next = !liked; setState(() => liked = next); _toggle('like', next); }, icon: Icon(Icons.favorite, color: liked ? Colors.pink : Colors.white)), IconButton(onPressed: () { final next = !saved; setState(() => saved = next); _toggle('save', next); }, icon: Icon(Icons.bookmark, color: saved ? Colors.orange : Colors.white)), IconButton(onPressed: () { final next = !reposted; setState(() => reposted = next); _toggle('repost', next); }, icon: Icon(Icons.repeat, color: reposted ? Colors.cyan : Colors.white))])),
        ]),
      );
}
class HorizontalPage extends StatelessWidget {
  const HorizontalPage({super.key});
  void _openPlayer(BuildContext context, PostRecord post) {
    const PostRepository().recordView(post.id);
    showDialog<void>(
        context: context,
        builder: (_) => Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(title: const Text('横動画')),
            body: Column(children: [
              Expanded(child: post.mediaUrl == null ? Center(child: Icon(Icons.play_circle, size: 96, color: Theme.of(context).colorScheme.primary)) : Center(child: VideoPreview(url: post.mediaUrl!))),
              const SizedBox(height: 16),
              Padding(padding: const EdgeInsets.all(16), child: Align(alignment: Alignment.centerLeft, child: Text(post.caption.isEmpty ? 'MeSee Vlog' : post.caption, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))),
            ]),
          ),
        ),
      );
  }
  @override
  Widget build(BuildContext context) => FutureBuilder<List<PostRecord>>(
        future: const PostRepository().fetchRecommended(),
        builder: (context, snapshot) {
          final posts = (snapshot.data ?? const <PostRecord>[]).where((post) => post.mediaType == 'video_horizontal').toList();
          if (snapshot.connectionState == ConnectionState.waiting && posts.isEmpty) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError && posts.isEmpty) return const Center(child: Text('横動画を読み込めませんでした。'));
          if (posts.isEmpty) return const Center(child: Text('横動画はまだありません'));
          return ListView(padding: const EdgeInsets.all(16), children: posts.asMap().entries.map((entry) {
            final index = entry.key, post = entry.value;
            return _HorizontalCard(post: post, color: Colors.primaries[index % Colors.primaries.length], onOpen: () => _openPlayer(context, post));
          }).toList());
        },
      );
}
class _HorizontalCard extends StatefulWidget {
  const _HorizontalCard({required this.post, required this.color, required this.onOpen});
  final PostRecord post; final Color color; final VoidCallback onOpen;
  @override State<_HorizontalCard> createState() => _HorizontalCardState();
}
class _HorizontalCardState extends State<_HorizontalCard> {
  bool liked = false, saved = false, reposted = false;
  @override void initState() { super.initState(); const PostRepository().recordImpression(widget.post.id); }
  void _react(String reaction, bool value) async { try { await const PostRepository().toggleReaction(widget.post.id, reaction, value); } catch (_) { if (mounted) setState(() { if (reaction == 'like') liked = !value; if (reaction == 'save') saved = !value; if (reaction == 'repost') reposted = !value; }); } }
  @override Widget build(BuildContext context) => Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [InkWell(onTap: widget.onOpen, child: AspectRatio(aspectRatio: 16 / 9, child: widget.post.mediaUrl == null ? Container(color: widget.color, child: const Center(child: Icon(Icons.play_circle_outline, size: 54))) : VideoPreview(url: widget.post.mediaUrl!))), ListTile(title: Text(widget.post.caption.isEmpty ? 'MeSee Vlog タイトル' : widget.post.caption), subtitle: Text('${widget.post.authorHandle} · ${widget.post.viewCount}回視聴'), trailing: Wrap(children: [IconButton(onPressed: () { final n = !liked; setState(() => liked = n); _react('like', n); }, icon: Icon(Icons.favorite, color: liked ? Colors.pink : null)), IconButton(onPressed: () { final n = !saved; setState(() => saved = n); _react('save', n); }, icon: Icon(Icons.bookmark, color: saved ? Colors.orange : null)), IconButton(onPressed: () { final n = !reposted; setState(() => reposted = n); _react('repost', n); }, icon: Icon(Icons.repeat, color: reposted ? Colors.cyan : null))]))]));
}
class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});
  @override State<MessagesPage> createState() => _MessagesPageState();
}
class _MessagesPageState extends State<MessagesPage> {
  late Future<List<Map<String, dynamic>>> _messages;
  StreamSubscription<List<Map<String, dynamic>>>? _messageSubscription;
  List<Map<String, dynamic>>? _liveMessages;
  @override void initState() { super.initState(); _reload(); }
  void _reload() {
    _messages = const PostRepository().fetchMessages();
    if (!AppConfig.hasSupabaseConfig) return;
    _messageSubscription?.cancel();
    _messageSubscription = Supabase.instance.client.from('messages').stream(primaryKey: ['id']).order('created_at', ascending: false).limit(50).listen((rows) {
      if (mounted) setState(() => _liveMessages = rows);
    });
  }
  @override void dispose() { _messageSubscription?.cancel(); super.dispose(); }
  Future<void> _openComposer() async {
    await showDialog<void>(context: context, builder: (_) => const _MessageComposerDialog());
    if (mounted) setState(_reload);
  }
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
        future: _messages,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('メッセージを読み込めませんでした。\n${snapshot.error}'));
          final messages = _liveMessages ?? snapshot.data ?? const <Map<String, dynamic>>[];
          final content = messages.isEmpty && AppConfig.hasSupabaseConfig ? const Center(child: Text('メッセージはまだありません')) : messages.isEmpty ? ListView(padding: const EdgeInsets.all(16), children: const [Text('MESSAGES', style: TextStyle(color: Colors.white54, letterSpacing: 2)), ListTile(leading: CircleAvatar(child: Text('MS')), title: Text('@sora.movie'), subtitle: Text('開発用メッセージ'))]) : ListView(padding: const EdgeInsets.all(16), children: [const Text('MESSAGES', style: TextStyle(color: Colors.white54, letterSpacing: 2)), ...messages.map((message) => ListTile(leading: const CircleAvatar(child: Text('M')), title: Text(message['body'] as String? ?? ''), subtitle: Text('${message['created_at'] ?? ''}')))]);
          return Stack(children: [content, if (AppConfig.hasSupabaseConfig) Positioned(right: 18, bottom: 18, child: FloatingActionButton(onPressed: _openComposer, child: const Icon(Icons.edit))) ]);
        },
      );
}

class _MessageComposerDialog extends StatefulWidget { const _MessageComposerDialog(); @override State<_MessageComposerDialog> createState() => _MessageComposerDialogState(); }
class _MessageComposerDialogState extends State<_MessageComposerDialog> {
  final username = TextEditingController(), body = TextEditingController(); bool busy = false; String? error;
  Future<void> send() async { if (body.text.trim().isEmpty || username.text.trim().isEmpty) { setState(() => error = '送信先と本文を入力してください。'); return; } setState(() { busy = true; error = null; }); try { await const PostRepository().sendMessage(username: username.text, body: body.text); if (mounted) Navigator.pop(context); } catch (exception) { if (mounted) setState(() => error = exception.toString()); } finally { if (mounted) setState(() => busy = false); } }
  @override void dispose() { username.dispose(); body.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AlertDialog(title: const Text('メッセージを送る'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: username, decoration: const InputDecoration(labelText: '@ユーザーネーム')), TextField(controller: body, maxLines: 4, decoration: const InputDecoration(labelText: '本文')), if (error != null) Text(error!, style: const TextStyle(color: Colors.redAccent))]), actions: [TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('キャンセル')), FilledButton(onPressed: busy ? null : send, child: Text(busy ? '送信中…' : '送信'))]);
}
class _NotificationsDialog extends StatelessWidget {
  const _NotificationsDialog();
  String _label(String kind) => switch (kind) { 'like' => 'あなたの投稿にいいねしました', 'save' => 'あなたの投稿を保存しました', 'repost' => 'あなたの投稿を再投稿しました', 'follow' => 'あなたをフォローしました', _ => '新しい通知があります' };
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('通知'),
        content: SizedBox(
          width: 360,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: const PostRepository().fetchNotifications(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return Text('通知を読み込めませんでした。\n${snapshot.error}');
              final items = snapshot.data ?? const <Map<String, dynamic>>[];
              if (items.isEmpty) return const Text('通知はありません');
              return ListView(
                shrinkWrap: true,
                children: items.map((item) {
                  final actor = item['profiles'];
                  final username = actor is Map ? actor['username'] : null;
                  final kind = item['kind'] as String? ?? '';
                  return ListTile(leading: const Icon(Icons.notifications_none), title: Text(username == null ? _label(kind) : '@$username'), subtitle: Text(_label(kind)));
                }).toList(),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () async { try { await const PostRepository().markNotificationsRead(); if (context.mounted) Navigator.pop(context); } catch (exception) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('既読処理に失敗しました: $exception'))); } }, child: const Text('すべて既読')), TextButton(onPressed: () => Navigator.pop(context), child: const Text('閉じる'))],
      );
}
class ProfilePage extends StatefulWidget { const ProfilePage({super.key}); @override State<ProfilePage> createState() => _ProfilePageState(); }
class _ProfilePageState extends State<ProfilePage> {
  late Future<List<PostRecord>> posts; Map<String, dynamic>? profile, stats; String selected = 'own', sort = 'latest';
  @override void initState() { super.initState(); _reload(); }
  Future<List<PostRecord>> _loadPosts() { final popular = sort == 'popular'; return selected == 'own' ? const PostRepository().fetchOwnPosts(popular: popular) : selected == 'vertical_video' ? const PostRepository().fetchOwnPosts(kind: 'vertical_video', popular: popular) : selected == 'horizontal_video' ? const PostRepository().fetchOwnPosts(kind: 'horizontal_video', popular: popular) : selected == 'text' ? const PostRepository().fetchOwnPosts(kind: 'text', popular: popular) : const PostRepository().fetchReactionPosts(selected); }
  void _reload() { posts = _loadPosts(); const PostRepository().fetchCurrentProfile().then((value) { if (mounted) setState(() => profile = value); }); const PostRepository().fetchProfileStats().then((value) { if (mounted) setState(() => stats = value); }); }
  Future<void> _deletePost(PostRecord post) async { final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('投稿を削除しますか？'), content: const Text('削除後は公開フィードから表示されなくなります。'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('削除'))])); if (ok != true) return; try { await const PostRepository().deleteOwnPost(post.id); if (mounted) { setState(_reload); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('投稿を削除しました'))); } } catch (exception) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('削除に失敗しました: $exception'))); } }
  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    Container(height: 116, decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), image: profile?['header_url'] is String && (profile!['header_url'] as String).isNotEmpty ? DecorationImage(image: NetworkImage(profile!['header_url'] as String), fit: BoxFit.cover, colorFilter: const ColorFilter.mode(Colors.black38, BlendMode.darken)) : null, gradient: profile?['header_url'] == null ? const LinearGradient(colors: [Color(0xff24153f), Color(0xff5b244b)]) : null)),
    const SizedBox(height: 12),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text((profile?['display_name'] as String?)?.isNotEmpty == true ? profile!['display_name'] as String : 'MeSee Creator', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), Text('@${profile?['username'] ?? 'mesee_creator'}', style: const TextStyle(color: Colors.white54))]),
      CircleAvatar(radius: 42, backgroundImage: profile?['avatar_url'] is String && (profile!['avatar_url'] as String).isNotEmpty ? NetworkImage(profile!['avatar_url'] as String) : null, child: profile?['avatar_url'] == null ? const Logo() : null),
    ]),
    const SizedBox(height: 20), Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [Text('${stats?['following_count'] ?? 0}\nフォロー中', textAlign: TextAlign.center), Text('${stats?['follower_count'] ?? 0}\nフォロワー', textAlign: TextAlign.center), Text('${stats?['like_count'] ?? 0}\nいいね', textAlign: TextAlign.center)]), const SizedBox(height: 20),
    FilledButton(onPressed: () async { await showDialog<void>(context: context, builder: (_) => const _ProfileEditDialog()); if (mounted) setState(_reload); }, child: const Text('プロフィールを編集')),
    if (AppConfig.hasSupabaseConfig) OutlinedButton.icon(onPressed: () => showDialog<void>(context: context, builder: (_) => const _CreatorCenterDialog()), icon: const Icon(Icons.insights_outlined), label: const Text('クリエイターセンター')),
    if (AppConfig.hasSupabaseConfig) OutlinedButton.icon(onPressed: () => showDialog<void>(context: context, builder: (_) => const _NotificationSettingsDialog()), icon: const Icon(Icons.notifications_outlined), label: const Text('通知設定')),
    if (AppConfig.hasSupabaseConfig) OutlinedButton.icon(onPressed: () => showDialog<void>(context: context, builder: (_) => const _AccountDeletionDialog()), icon: const Icon(Icons.delete_forever_outlined), label: const Text('アカウント削除')),
    if (AppConfig.hasSupabaseConfig) OutlinedButton.icon(onPressed: () => Supabase.instance.client.auth.signOut(), icon: const Icon(Icons.logout), label: const Text('ログアウト')),
    const SizedBox(height: 12), Row(children: [const Text('表示順'), const SizedBox(width: 8), DropdownButton<String>(value: sort, items: const [DropdownMenuItem(value: 'latest', child: Text('最新の投稿')), DropdownMenuItem(value: 'popular', child: Text('人気順'))], onChanged: (value) { if (value != null) setState(() { sort = value; posts = _loadPosts(); }); })]), SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [for (final item in const [('own', '自分', Icons.grid_view), ('vertical_video', '縦動画', Icons.smartphone), ('horizontal_video', '横動画', Icons.ondemand_video), ('text', 'つぶやき', Icons.chat_bubble_outline), ('like', 'いいね', Icons.favorite), ('save', '保存', Icons.bookmark), ('repost', '再投稿', Icons.repeat)]) Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(item.$2), avatar: Icon(item.$3, size: 16), selected: selected == item.$1, onSelected: (_) { setState(() { selected = item.$1; posts = _loadPosts(); }); }))])),
    FutureBuilder<List<PostRecord>>(future: posts, builder: (context, snapshot) { final items = snapshot.data ?? const <PostRecord>[]; if (snapshot.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())); if (items.isEmpty) return const Padding(padding: EdgeInsets.all(24), child: Text('該当する投稿はありません')); return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: items.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4), itemBuilder: (_, i) => GestureDetector(onLongPress: selected == 'own' ? () => _deletePost(items[i]) : null, child: Card(child: Center(child: Icon(items[i].mediaType == 'text' ? Icons.chat_bubble_outline : Icons.play_arrow))))); }),
  ]);
}
class _CreatorCenterDialog extends StatelessWidget {
  const _CreatorCenterDialog();
  @override Widget build(BuildContext context) => AlertDialog(title: const Text('クリエイターセンター'), content: FutureBuilder<Map<String, dynamic>?>(future: const PostRepository().fetchCreatorAnalytics(), builder: (context, snapshot) { if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())); final data = snapshot.data; if (data == null) return const Text('分析データを取得できませんでした。'); return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('投稿数: ${data['total_posts'] ?? 0}'), Text('再生数: ${data['total_views'] ?? 0}'), Text('インプレッション: ${data['total_impressions'] ?? 0}'), Text('いいね: ${data['total_likes'] ?? 0}'), Text('推定収益: ${data['creator_revenue'] ?? 0}'),]); }), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('閉じる'))]);
}
class _AccountDeletionDialog extends StatefulWidget { const _AccountDeletionDialog(); @override State<_AccountDeletionDialog> createState() => _AccountDeletionDialogState(); }
class _AccountDeletionDialogState extends State<_AccountDeletionDialog> {
  bool busy = false;
  Future<void> request() async { setState(() => busy = true); try { await const PostRepository().requestAccountDeletion(); if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('アカウント削除を申請しました。30日以内は取消できます。'))); } } catch (exception) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('申請に失敗しました: $exception'))); } finally { if (mounted) setState(() => busy = false); } }
  Future<void> cancel() async { setState(() => busy = true); try { await const PostRepository().cancelAccountDeletion(); if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('アカウント削除申請を取り消しました。'))); } } catch (exception) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('取消に失敗しました: $exception'))); } finally { if (mounted) setState(() => busy = false); } }
  @override Widget build(BuildContext context) => AlertDialog(title: const Text('アカウント削除'), content: const Text('削除を申請すると30日後に処理されます。期間内は取消できます。'), actions: [TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('閉じる')), OutlinedButton(onPressed: busy ? null : cancel, child: const Text('申請を取り消す')), FilledButton(onPressed: busy ? null : request, child: Text(busy ? '処理中…' : '削除を申請'))]);
}
class _NotificationSettingsDialog extends StatefulWidget { const _NotificationSettingsDialog(); @override State<_NotificationSettingsDialog> createState() => _NotificationSettingsDialogState(); }
class _NotificationSettingsDialogState extends State<_NotificationSettingsDialog> {
  final values = <String, bool>{'notify_likes': true, 'notify_saves': true, 'notify_followers': true, 'notify_reposts': true, 'notify_messages': true}; bool busy = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { try { final data = await const PostRepository().fetchUserSettings(); if (!mounted) return; if (data != null) { for (final key in values.keys) { values[key] = data[key] as bool? ?? true; } } setState(() => busy = false); } catch (_) { if (mounted) { setState(() => busy = false); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('通知設定を読み込めませんでした。'))); } } }
  Future<void> save() async { setState(() => busy = true); try { await const PostRepository().updateUserSettings(values); if (mounted) Navigator.pop(context); } catch (exception) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('通知設定の保存に失敗しました: $exception'))); } finally { if (mounted) setState(() => busy = false); } }
  @override Widget build(BuildContext context) => AlertDialog(title: const Text('通知設定'), content: Column(mainAxisSize: MainAxisSize.min, children: [for (final item in const [('notify_likes', 'いいね'), ('notify_saves', '保存'), ('notify_followers', 'フォロー'), ('notify_reposts', '再投稿'), ('notify_messages', 'メッセージ')]) SwitchListTile(title: Text(item.$2), value: values[item.$1] ?? true, onChanged: busy ? null : (v) => setState(() => values[item.$1] = v))]), actions: [TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('キャンセル')), FilledButton(onPressed: busy ? null : save, child: Text(busy ? '読み込み中…' : '保存'))]);
}
class _ProfileEditDialog extends StatefulWidget { const _ProfileEditDialog(); @override State<_ProfileEditDialog> createState() => _ProfileEditDialogState(); }
class _ProfileEditDialogState extends State<_ProfileEditDialog> {
  final name = TextEditingController(), username = TextEditingController(), bio = TextEditingController(); final picker = ImagePicker(); XFile? avatar, header; bool busy = false, isPrivate = false; String? error;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { final current = await const PostRepository().fetchCurrentProfile(); if (!mounted || current == null) return; name.text = current['display_name'] as String? ?? ''; username.text = current['username'] as String? ?? ''; bio.text = current['bio'] as String? ?? ''; setState(() => isPrivate = current['is_private'] as bool? ?? false); }
  Future<void> choose(bool isHeader) async { try { final selected = await picker.pickImage(source: ImageSource.gallery); if (selected != null && mounted) setState(() { if (isHeader) { header = selected; } else { avatar = selected; } }); } catch (_) { if (mounted) setState(() => error = '画像へのアクセスが許可されていません。'); } }
  Future<void> save() async { setState(() { busy = true; error = null; }); try { await const PostRepository().updateProfile(displayName: name.text, username: username.text, bio: bio.text, isPrivate: isPrivate, avatar: avatar, header: header); if (mounted) Navigator.pop(context); } catch (exception) { if (mounted) setState(() => error = exception.toString()); } finally { if (mounted) setState(() => busy = false); } }
  @override void dispose() { name.dispose(); username.dispose(); bio.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AlertDialog(title: const Text('プロフィールを編集'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: '名前')), TextField(controller: username, decoration: const InputDecoration(labelText: '@ユーザーネーム')), TextField(controller: bio, maxLines: 3, decoration: const InputDecoration(labelText: '自己紹介')), Row(children: [Expanded(child: OutlinedButton.icon(onPressed: busy ? null : () => choose(false), icon: const Icon(Icons.person_outline), label: Text(avatar == null ? 'アイコン' : '選択済み'))), const SizedBox(width: 8), Expanded(child: OutlinedButton.icon(onPressed: busy ? null : () => choose(true), icon: const Icon(Icons.image_outlined), label: Text(header == null ? 'ヘッダー' : '選択済み')))]), SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('非公開アカウント'), value: isPrivate, onChanged: busy ? null : (value) => setState(() => isPrivate = value)), if (error != null) Text(error!, style: const TextStyle(color: Colors.redAccent))]), actions: [TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('キャンセル')), FilledButton(onPressed: busy ? null : save, child: Text(busy ? '保存中…' : '保存'))]);
}
class CreateSheet extends StatelessWidget {
  const CreateSheet({super.key});
  void _openComposer(BuildContext context, String title, String hint) { Navigator.pop(context); showDialog<void>(context: context, builder: (_) => const _LiveSetupDialog()); }
  void _openMediaComposer(BuildContext context) { Navigator.pop(context); showDialog<void>(context: context, builder: (_) => const _MediaPostDialog()); }
  void _openTextComposer(BuildContext context) { Navigator.pop(context); showDialog<void>(context: context, builder: (_) => const _TextPostDialog()); }
  @override Widget build(BuildContext context) => SafeArea(child: Wrap(children: [ListTile(leading: const Icon(Icons.camera_alt_outlined), title: const Text('写真・動画を撮影'), onTap: () => _openMediaComposer(context)), ListTile(leading: const Icon(Icons.text_fields), title: const Text('つぶやく'), onTap: () => _openTextComposer(context)), ListTile(leading: const Icon(Icons.live_tv_outlined), title: const Text('LIVE'), onTap: () => _openComposer(context, 'LIVE配信を設定', '配信タイトル・説明文を入力'))]));
}
class _LiveSetupDialog extends StatefulWidget { const _LiveSetupDialog(); @override State<_LiveSetupDialog> createState() => _LiveSetupDialogState(); }
class _LiveSetupDialogState extends State<_LiveSetupDialog> {
  final title = TextEditingController(), description = TextEditingController(); String visibility = 'public'; bool busy = false; String? error;
  Future<void> save() async { if (title.text.trim().isEmpty) { setState(() => error = '配信タイトルを入力してください。'); return; } setState(() { busy = true; error = null; }); try { final liveId = await const PostRepository().createLivePost(title: title.text, description: description.text, visibility: visibility); if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('LIVE配信設定を保存しました。コメント欄を開けます。'))); if (liveId != null) { await showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => _LiveCommentsSheet(livePostId: liveId, title: title.text.trim())); } } } catch (exception) { if (mounted) setState(() => error = exception.toString()); } finally { if (mounted) setState(() => busy = false); } }
  @override void dispose() { title.dispose(); description.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AlertDialog(title: const Text('LIVE配信を設定'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: title, decoration: const InputDecoration(labelText: 'タイトル')), TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: '説明文・ハッシュタグ')), DropdownButtonFormField<String>(initialValue: visibility, items: const [DropdownMenuItem(value: 'public', child: Text('公開')), DropdownMenuItem(value: 'followers', child: Text('フォロワーのみ')), DropdownMenuItem(value: 'private', child: Text('非公開'))], onChanged: busy ? null : (value) => setState(() => visibility = value ?? 'public')), if (error != null) Text(error!, style: const TextStyle(color: Colors.redAccent))]), actions: [TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('キャンセル')), FilledButton(onPressed: busy ? null : save, child: Text(busy ? '保存中…' : '設定を保存'))]);
}

class _LiveCommentsSheet extends StatefulWidget {
  const _LiveCommentsSheet({required this.livePostId, required this.title});
  final String livePostId;
  final String title;
  @override State<_LiveCommentsSheet> createState() => _LiveCommentsSheetState();
}

class _LiveCommentsSheetState extends State<_LiveCommentsSheet> {
  final controller = TextEditingController();
  bool sending = false;
  Future<void> send() async {
    final body = controller.text.trim();
    if (body.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      await const PostRepository().sendLiveComment(livePostId: widget.livePostId, body: body);
      controller.clear();
    } catch (exception) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('コメントを送信できませんでした: $exception')));
    } finally { if (mounted) setState(() => sending = false); }
  }
  @override void dispose() { controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => SafeArea(child: SizedBox(height: MediaQuery.sizeOf(context).height * .72, child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [Row(children: [Expanded(child: Text(widget.title, style: Theme.of(context).textTheme.titleLarge)), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))]), const Divider(), Expanded(child: StreamBuilder<List<Map<String, dynamic>>>(stream: const PostRepository().liveComments(widget.livePostId), builder: (context, snapshot) { final comments = snapshot.data ?? const <Map<String, dynamic>>[]; if (!AppConfig.hasSupabaseConfig) return const Center(child: Text('Supabase接続後にLIVEコメントを利用できます。')); if (comments.isEmpty) return const Center(child: Text('コメントはまだありません')); return ListView.builder(itemCount: comments.length, itemBuilder: (_, index) => ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text(comments[index]['body'] as String? ?? ''), subtitle: Text(comments[index]['created_at'] as String? ?? ''))); })), TextField(controller: controller, maxLength: 500, textInputAction: TextInputAction.send, onSubmitted: (_) => send(), decoration: InputDecoration(hintText: 'LIVEコメントを入力', suffixIcon: IconButton(onPressed: sending ? null : send, icon: sending ? const CircularProgressIndicator() : const Icon(Icons.send))))]))));
}

class _MediaPostDialog extends StatefulWidget { const _MediaPostDialog(); @override State<_MediaPostDialog> createState() => _MediaPostDialogState(); }
class _MediaPostDialogState extends State<_MediaPostDialog> {
  final picker = ImagePicker(); final title = TextEditingController(); XFile? file; String kind = 'photo'; bool busy = false; String? error;
  Future<void> chooseGallery() async { try { final selected = await picker.pickMedia(); if (selected == null || !mounted) return; final mime = selected.mimeType ?? ''; final isVideo = mime.startsWith('video/') || RegExp(r'\.(mp4|mov|m4v|webm|avi)$', caseSensitive: false).hasMatch(selected.name); final valid = kind == 'photo' ? !isVideo : isVideo; if (!valid) { setState(() => error = kind == 'photo' ? '写真を選択してください。' : '動画を選択してください。'); return; } setState(() { file = selected; error = null; }); } catch (_) { if (mounted) setState(() => error = 'メディアへのアクセスが許可されていません。端末の設定を確認してください。'); } }
  Future<void> chooseCamera() async { try { final selected = (kind == 'photo') ? await picker.pickImage(source: ImageSource.camera) : await picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(minutes: 10)); if (selected != null && mounted) setState(() { file = selected; error = null; }); } catch (_) { if (mounted) setState(() => error = 'カメラへのアクセスが許可されていません。端末の設定を確認してください。'); } }
  Future<void> save() async { if (file == null) { setState(() => error = '写真または動画を選択してください。'); return; } setState(() { busy = true; error = null; }); try { await const PostRepository().createMediaPost(file: file!, kind: kind, title: title.text); if (mounted) Navigator.pop(context); } catch (exception) { if (mounted) setState(() => error = exception.toString()); } finally { if (mounted) setState(() => busy = false); } }
  @override void dispose() { title.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AlertDialog(title: const Text('写真・動画を投稿'), content: Column(mainAxisSize: MainAxisSize.min, children: [DropdownButtonFormField<String>(initialValue: kind, items: const [DropdownMenuItem(value: 'photo', child: Text('写真')), DropdownMenuItem(value: 'vertical_video', child: Text('縦動画')), DropdownMenuItem(value: 'horizontal_video', child: Text('横動画'))], onChanged: busy ? null : (value) => setState(() { kind = value ?? 'photo'; file = null; error = null; })), TextField(controller: title, decoration: const InputDecoration(labelText: 'タイトル')), const SizedBox(height: 12), Row(children: [Expanded(child: OutlinedButton.icon(onPressed: busy ? null : chooseCamera, icon: const Icon(Icons.camera_alt_outlined), label: const Text('撮影'))), const SizedBox(width: 8), Expanded(child: OutlinedButton.icon(onPressed: busy ? null : chooseGallery, icon: const Icon(Icons.photo_library_outlined), label: Text(file == null ? '選択' : file!.name))) ]), if (error != null) Text(error!, style: const TextStyle(color: Colors.redAccent))]), actions: [TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('キャンセル')), FilledButton(onPressed: busy ? null : save, child: Text(busy ? 'アップロード中…' : '投稿'))]);
}

class _TextPostDialog extends StatefulWidget { const _TextPostDialog(); @override State<_TextPostDialog> createState() => _TextPostDialogState(); }
class _TextPostDialogState extends State<_TextPostDialog> {
  final title = TextEditingController(), body = TextEditingController(); bool busy = false; String? error;
  Future<void> save() async { if (body.text.trim().isEmpty) { setState(() => error = '本文を入力してください。'); return; } setState(() { busy = true; error = null; }); try { await const PostRepository().createTextPost(title: title.text, body: body.text); if (mounted) Navigator.pop(context); } catch (exception) { if (mounted) setState(() => error = exception.toString()); } finally { if (mounted) setState(() => busy = false); } }
  @override void dispose() { title.dispose(); body.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AlertDialog(title: const Text('つぶやきを投稿'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: title, decoration: const InputDecoration(labelText: 'タイトル')), TextField(controller: body, maxLines: 4, decoration: const InputDecoration(labelText: '本文')), if (error != null) Text(error!, style: const TextStyle(color: Colors.redAccent))]), actions: [TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('キャンセル')), FilledButton(onPressed: busy ? null : save, child: Text(busy ? '保存中…' : '投稿'))]);
}
