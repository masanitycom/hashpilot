# メールシステム調査レポート

調査日: 2025年10月9日
調査対象: HASHPILOTシステムのメール機能

---

## 📋 現状分析

### 1. 現在のメールシステム構成

#### 新規登録メール（認証メール）
- **送信元**: Supabase Auth（現在: hashpilotnft@gmail.com 経由と推測）
- **実装方法**: `supabase.auth.signUp()` を使用
- **設定場所**: Supabase ダッシュボード > Authentication > Email Templates
- **変更可能性**: ✅ 可能（Supabaseダッシュボードで設定）

#### NFT承認メール
- **送信元**: `HASHPILOT <send@hashpilot.net>` (Resend API経由)
- **実装場所**: `/supabase/functions/send-approval-email/index.ts`
- **API**: Resend (https://api.resend.com/emails)
- **現状**: ❌ 失敗している（環境変数 RESEND_API_KEY の問題と推測）

---

## 🎯 要望の実現可能性

### ✅ 実現可能な機能

#### 1. auth@hashpilot.biz からのメール送信
**新規登録・認証メール**
- **方法A（推奨）**: SupabaseダッシュボードでカスタムSMTP設定
  - Settings > Authentication > SMTP Settings
  - auth@hashpilot.biz のSMTP情報を設定
  - Gmailから移行可能
  - **影響**: 既存システムに影響なし ✅

**NFT承認メール**
- **方法**: Resend APIで送信元を変更
  - Resendで auth@hashpilot.biz のドメイン認証
  - Edge Functionのコード1行変更: `from: 'HASHPILOT <auth@hashpilot.biz>'`
  - **影響**: Edge Function再デプロイのみ ✅

#### 2. 報酬送金完了メール (withdrawal@hashpilot.biz)
- **実装方法**: 新しいEdge Function作成
  - `/supabase/functions/send-withdrawal-email/index.ts`
  - 既存の承認メール機能をコピー&修正
  - 出金完了処理から呼び出し
- **影響**: 新機能追加のため既存システム影響なし ✅

#### 3. 一括送信・個別送信機能 (noreply@hashpilot.biz)
- **実装方法**: 新しい管理画面ページ作成
  - `/app/admin/email-broadcast/page.tsx` (新規)
  - Resend APIで一括送信
  - テンプレート機能（HTML対応）
  - 送信履歴管理
  - Reply-To ヘッダーなし（返信不可）
- **影響**: 完全に新規機能のため既存システム影響なし ✅

---

## 🛠 実装の難易度と必要な作業

### 優先度1: auth@hashpilot.biz への移行

#### A. Supabase Auth（新規登録メール）
**難易度**: ⭐☆☆（簡単）
**作業時間**: 10分
**手順**:
1. Supabaseダッシュボードにログイン
2. Settings > Authentication > SMTP Settings
3. auth@hashpilot.biz のSMTP情報を入力
   - Host: (メールプロバイダーから提供)
   - Port: 587 または 465
   - Username: auth@hashpilot.biz
   - Password: (メールプロバイダーから提供)
4. テスト送信で確認

**リスク**: なし（設定のみ）

#### B. Resend API（承認メール）
**難易度**: ⭐⭐☆（中程度）
**作業時間**: 30分
**手順**:
1. Resend ダッシュボードでドメイン認証
   - hashpilot.biz のDNS設定が必要
2. auth@hashpilot.biz を認証
3. Edge Function修正（1行のみ）
4. Supabase Edge Function再デプロイ

**リスク**: 低（Edge Function再デプロイのみ）

### 優先度2: 送金完了メール機能

**難易度**: ⭐⭐☆（中程度）
**作業時間**: 1-2時間
**必要な作業**:
1. withdrawal@hashpilot.biz をResendで認証
2. Edge Function作成（承認メールをベース）
3. 出金完了処理に組み込み
4. メールテンプレート作成

**リスク**: 低（新機能追加のみ）

### 優先度3: 一括送信・個別送信機能

**難易度**: ⭐⭐⭐（やや複雑）
**作業時間**: 3-4時間
**送信元**: noreply@hashpilot.biz（返信不可）
**必要な作業**:
1. noreply@hashpilot.biz をResendで認証
2. 管理画面ページ作成
3. メールテンプレート管理
4. 一括送信処理（バッチ処理）
5. 送信履歴テーブル作成
6. 送信エラー処理
7. Reply-Toヘッダー無し設定

**リスク**: 中（新しいテーブル追加、バッチ処理）

---

## ⚠️ 注意事項

### Resendの制限
- 無料プラン: 100通/日、3,000通/月
- 有料プラン推奨: $20/月で50,000通
- ドメイン認証必須（hashpilot.biz）

### DNSレコード設定が必要
```
hashpilot.biz           → Resendのドメイン認証レコード
auth@hashpilot.biz      → 認証済み送信元として登録
withdrawal@hashpilot.biz → 認証済み送信元として登録
noreply@hashpilot.biz   → 認証済み送信元として登録
```

### 本番環境への影響
- **最小限**: 設定変更とEdge Function再デプロイのみ
- **テスト必須**: 各メール送信機能をステージング環境で確認
- **ロールバック**: 既存のコードはそのまま残すため、問題時は設定を戻すだけ

---

## 📝 推奨実装順序

1. **auth@hashpilot.biz への移行**（新規登録・承認メール）
   - 影響: 最小
   - 効果: 即座にブランディング向上

2. **withdrawal@hashpilot.biz の送金完了メール**
   - 新機能として追加
   - ユーザー体験向上

3. **noreply@hashpilot.biz の一括送信機能**
   - 管理効率化
   - マーケティング施策・お知らせ配信に活用
   - 返信不可（noreply）で一方向通知

---

## ✅ 結論

**全て実現可能です。既存システムへの影響は最小限です。**

- auth@hashpilot.biz への移行: **すぐに実装可能**
- 送金完了メール: **実装可能（1-2時間）**
- 一括送信機能: **実装可能（3-4時間）**

本番開始前に実装する場合は、**優先度1（auth@ への移行）**のみを先に実施し、
他の機能は本番稼働後に段階的に追加することを推奨します。

---

## 📧 メールアドレス構成（最終版）

| メールアドレス | 用途 | 返信 | 実装優先度 |
|--------------|------|------|-----------|
| **auth@hashpilot.biz** | 新規登録認証メール、NFT承認メール | - | ⭐⭐⭐ 高 |
| **withdrawal@hashpilot.biz** | 報酬送金完了メール | - | ⭐⭐ 中 |
| **noreply@hashpilot.biz** | 一括送信・お知らせ配信 | ❌ 不可 | ⭐ 低 |

※ info@hashpilot.biz と support@hashpilot.biz は使用しない
