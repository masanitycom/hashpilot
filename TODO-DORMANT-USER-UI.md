# 休眠（解約）ユーザーのUI対応

作成日: 2025-12-12
**実装完了日: 2025-12-12**

## 背景

全NFTを買い取り（売却）したユーザーは「休眠ユーザー」となる。
- `users.is_active_investor = FALSE` で判定
- トリガーにより自動更新される（`trigger_update_active_status`）
- 紹介ツリー上の位置は維持され、紹介報酬は会社アカウント（7A9637）が受け取る

投資を再開するには、新しい紹介リンクから新規アカウントを作成する必要がある。

## 実装内容

### 1. ダッシュボード: 解約バナー表示

**条件:** `is_active_investor = FALSE`

**表示内容:**
```
⚠️ アカウント解約済み

全てのNFTを売却したため、このアカウントは解約状態です。
過去の履歴は閲覧できますが、新規投資はできません。

投資を再開するには、新しい紹介リンクから
新規アカウントを作成してください。
```

**ファイル:** `app/dashboard/page.tsx`

### 2. NFT購入ページ: アクセス不可

**条件:** `is_active_investor = FALSE`

**表示内容:**
```
このアカウントではNFTの購入は出来ません。
```

**ファイル:** `app/nft/page.tsx`（またはNFT購入ページ）

### 3. 紹介リンク: 無効化

**条件:** `is_active_investor = FALSE`

**対応:**
- 紹介リンクを非表示にする
- または「無効」と表示して使用不可にする
- QRコードも非表示

**ファイル:**
- `app/profile/page.tsx`
- `app/dashboard/page.tsx`（紹介リンク表示箇所）

## 休眠ユーザーができること

- ログイン
- 過去の履歴確認（日利、紹介報酬など）
- 残高があれば出金

## 休眠ユーザーができないこと

- NFT購入
- 紹介リンクの使用（新規ユーザーを招待できない）

## 関連ファイル

- `scripts/implement-dormant-user-company-bonus.sql` - 休眠ユーザーシステム実装
- `scripts/update-referral-calculation-for-dormant.sql` - 紹介報酬計算（休眠対応）

## 判定に使用するフィールド

```sql
-- usersテーブル
is_active_investor BOOLEAN  -- TRUE: アクティブ、FALSE: 休眠（解約）
```

## 確認用SQL

```sql
-- 休眠ユーザー一覧
SELECT user_id, email, is_active_investor
FROM users
WHERE is_active_investor = FALSE;

-- 特定ユーザーの状態確認
SELECT
  u.user_id,
  u.email,
  u.is_active_investor,
  u.has_approved_nft,
  ac.total_nft_count
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE u.user_id = '3194C4';
```
