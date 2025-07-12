# 安全なユーザー削除機能

## 🔒 安全性重視のアプローチ

このソリューションは**既存のデータベース構造を一切変更せず**、関数レベルでのみ安全な削除を実現します。

### ❌ 実行しないもの
- 外部キー制約の変更
- CASCADE削除の有効化  
- データベーススキーマの変更

### ✅ 実行するもの
- 安全な順序での手動削除処理
- 管理者権限チェック
- 詳細な削除ログ記録

## 🛠️ 実装方法

### 1. 安全な削除関数の適用

```sql
-- /scripts/safe-user-deletion-function-only.sql を実行
\i /mnt/d/HASHPILOT/scripts/safe-user-deletion-function-only.sql
```

### 2. 削除の実行方法

#### 管理画面から（推奨）
- `/admin/users` ページの削除ボタンを使用
- 自動的に `delete_user_safely()` 関数が呼ばれます

#### 直接SQL実行
```sql
SELECT * FROM delete_user_safely('ユーザーID', '管理者メール');

-- 例:
SELECT * FROM delete_user_safely('ABC123', 'admin@example.com');
```

## 🔄 削除処理の順序

安全な削除のため、以下の順序で処理されます：

1. **管理者権限確認**
   - `admins` テーブルでの権限チェック
   - 緊急アクセス権限（basarasystems@gmail.com等）

2. **紹介関係の解除**
   ```sql
   UPDATE users SET referrer_user_id = NULL WHERE referrer_user_id = 削除対象;
   ```

3. **子テーブルから順次削除**
   ```sql
   DELETE FROM buyback_requests WHERE user_id = 削除対象;
   DELETE FROM withdrawal_requests WHERE user_id = 削除対象;
   DELETE FROM user_daily_profit WHERE user_id = 削除対象;
   DELETE FROM purchases WHERE user_id = 削除対象;
   DELETE FROM system_logs WHERE user_id = 削除対象;
   DELETE FROM affiliate_cycle WHERE user_id = 削除対象;  -- 重要
   ```

4. **ユーザー本体の削除**
   ```sql
   DELETE FROM users WHERE user_id = 削除対象;
   ```

## 📊 削除前の確認機能

関数実行前に、以下のデータを確認できます：

```sql
-- 削除候補ユーザーの確認
SELECT 
    u.user_id,
    u.email,
    u.total_purchases,
    EXISTS(SELECT 1 FROM affiliate_cycle WHERE user_id = u.user_id) as has_affiliate_cycle,
    (SELECT COUNT(*) FROM purchases WHERE user_id = u.user_id) as purchases_count,
    (SELECT COUNT(*) FROM users WHERE referrer_user_id = u.user_id) as referrals_count
FROM users u
WHERE u.email = '削除対象のメール';
```

## 🚨 エラーハンドリング

### よくあるエラーと対処法

1. **権限エラー**
   ```
   ERROR: 管理者権限がありません
   ```
   → 管理者メールアドレスを確認

2. **ユーザーが見つからない**
   ```
   ERROR: ユーザーが見つかりません
   ```
   → user_id を正確に入力

3. **外部キー制約エラー**
   ```
   ERROR: 削除エラー: ... foreign key constraint ...
   ```
   → 関数内の削除順序で自動処理されます

## 🔍 削除結果の確認

削除後、以下で結果を確認できます：

```sql
-- 削除ログの確認
SELECT * FROM system_logs 
WHERE operation = 'user_deleted_safely' 
ORDER BY created_at DESC 
LIMIT 10;

-- ユーザーが完全に削除されたか確認
SELECT COUNT(*) FROM users WHERE user_id = '削除したユーザーID';
-- 結果が 0 なら削除成功

-- 関連データも削除されたか確認
SELECT 
    (SELECT COUNT(*) FROM affiliate_cycle WHERE user_id = '削除したユーザーID') as affiliate_cycle,
    (SELECT COUNT(*) FROM purchases WHERE user_id = '削除したユーザーID') as purchases,
    (SELECT COUNT(*) FROM withdrawal_requests WHERE user_id = '削除したユーザーID') as withdrawals;
-- 全て 0 なら完全削除成功
```

## 🔧 管理画面での使用

`/app/admin/users/page.tsx` では自動的に以下の処理が行われます：

1. **詳細確認ダイアログ**
   - 削除されるデータの詳細表示
   - 取り消し不可の警告

2. **安全な削除実行**
   ```typescript
   const { data: result, error } = await supabase.rpc("delete_user_safely", {
     p_user_id: user.user_id,
     p_admin_email: currentUser.email
   })
   ```

3. **結果の表示**
   - 成功時：削除完了メッセージ
   - 失敗時：詳細なエラーメッセージ

## 💡 安全性の特徴

- ✅ **既存データ保護**: データベース構造は一切変更しません
- ✅ **権限制御**: 管理者のみが実行可能
- ✅ **順序制御**: 外部キー制約を考慮した正確な削除順序
- ✅ **完全ログ**: 削除処理の詳細を全記録
- ✅ **ロールバック**: エラー時は自動的に処理を中断
- ✅ **確認機能**: 削除前後でデータ状況を確認可能

この方法により、既存のデータベースを壊すことなく、安全にユーザー削除機能を提供できます。