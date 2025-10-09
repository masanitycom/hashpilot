-- ========== ユーザー残高と自動購入の保存場所を調査 ==========

-- 1. usersテーブルの構造（残高関連フィールド）
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'users'
AND column_name LIKE '%balance%'
ORDER BY ordinal_position;

-- 2. usersテーブルの構造（購入関連フィールド）
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'users'
AND column_name LIKE '%purchase%'
ORDER BY ordinal_position;

-- 3. nft_purchasesテーブルの構造（存在確認）
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'nft_purchases'
ORDER BY ordinal_position;

-- 4. affiliate_cycleテーブルの構造
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'affiliate_cycle'
ORDER BY ordinal_position;

-- 5. 自動購入履歴テーブルの候補を検索
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
AND (table_name LIKE '%auto%' OR table_name LIKE '%purchase%')
ORDER BY table_name;

-- 6. 実際のユーザーデータを1件サンプル表示（残高確認）
SELECT
  user_id,
  total_purchases,
  -- 残高関連フィールドを探す
  *
FROM users
WHERE total_purchases > 0
LIMIT 1;

-- 7. 最近の自動購入履歴を確認（10/8-10/10）
SELECT *
FROM user_daily_profit
WHERE date >= '2025-10-08'
AND date <= '2025-10-10'
ORDER BY date DESC, daily_profit DESC
LIMIT 5;

-- 8. RPC関数 get_auto_purchase_history の定義を確認
SELECT routine_name, routine_definition
FROM information_schema.routines
WHERE routine_name LIKE '%auto%purchase%'
AND routine_schema = 'public';
