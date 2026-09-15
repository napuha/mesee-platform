# MeSee 公開準備チェックリスト

## 完了済みの土台

- Flutterプロジェクトの最小UI
- ブラウザプロトタイプの主要操作
- 投稿・反応・視聴イベントのモデル
- Supabaseの段階的スキーマ
- RLS、通報、管理者操作ログ
- 収益分配のサーバー側集計関数

## 公開前に必ず実環境で確認する項目

- [x] Supabaseへ `001`〜`019` を順番に適用（`supabase db push`で最新確認済み）
- [x] Flutter SDKのロックを解消し、Dart解析・Flutterテスト・Debug APKビルドを実行（実機接続テストは別途）
- [ ] Authのメール・OAuth・年齢方針を設定
- [ ] Storageバケットと動画の公開/署名URLを設定（現在のリンク先DBでは`mesee-media`バケット行を確認できていないため、作成後にRLS・署名URLを実機確認する）
- [ ] 動画変換・サムネイル・ストリーミングを設定
- [ ] RealtimeでメッセージとLIVEコメントを実環境確認（メッセージとLIVEコメントのDB・購読・送信UIは実装済み、実際の配信transportは未実装）
- [ ] Push通知の証明書・Firebase設定を登録
- [ ] 広告SDKと広告収益イベントを登録
- [ ] Stripe等の支払・税務・本人確認を設定
- [ ] App Store / Google Playの未成年者・プライバシー申告を完了
- [x] Android/iOSのストア用アプリIDを `com.mesee.app` に統一

## Current implementation audit

- [x] Supabase authentication gate, sign-up, sign-in, and sign-out
- [x] Text post creation with server persistence
- [x] Photo/video selection or camera capture with Storage upload foundation
- [x] Reaction synchronization for like, save, and repost
- [x] Like, save, and repost controls on home, vertical, and horizontal feeds
- [x] Profile post filters for own, vertical, horizontal, text, liked, saved, and reposted posts
- [x] Own-post deletion with confirmation and failure feedback
- [x] Media-type validation for photo versus video uploads and permission-error handling
- [x] Client-side upload size guard (500 MB per file)
- [x] Network video initialization failure feedback without indefinite loading
- [x] View-complete event and server-side counters
- [x] Recommendation RPC using follows, engagement, freshness, and per-user view/reaction/skip history
- [x] Creator center entry point with post, view, like, and estimated-revenue analytics
- [x] Notification preference read/write for likes, saves, follows, reposts, and messages
- [x] Report submission requires a non-empty reason and surfaces save failures
- [x] Block-user action from post cards with protected persistence and error feedback
- [ ] Network video playback and resumable playback position
- [ ] Background video transcoding, thumbnails, and adaptive streaming
- [ ] Push notifications through FCM/APNs
- [ ] Live streaming transport (WebRTC等) と実配信中の視聴者コメント連携（コメントUI・Realtime購読/送信の基盤は実装済み）
- [ ] Production payment, ad mediation, tax, and creator payout verification
- [x] Reproducible Flutter release validation workflow (`.github/workflows/flutter-release.yml`)
- [x] Release workflow reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` from protected CI secrets
- [x] Automated public-release preflight (`tools/public-release-check.ps1`)
- [x] Flutter widget/repository tests (`flutter_tools.snapshot test --no-pub`), Debug APK, and signed Android App Bundle build verified
- [x] Public-release preflight checks the generated Debug APK and Release AAB artifacts
- [x] Android signing template without secrets (`android/key.properties.example`)
- [ ] 通報、削除、ブロック、アカウント削除を実機確認（アカウント削除申請・30日猶予UI/DBは実装済み）
- [x] フォロー通信失敗時のUI状態復元を実装
- [ ] iOS / Android実機でカメラ・マイク・通知権限を確認
- [ ] 負荷試験、クラッシュ収集、バックアップ、復旧手順を確認

実際のサービスキーをリポジトリへ保存せず、CI/CDまたはホスティングのSecretへ登録する。
