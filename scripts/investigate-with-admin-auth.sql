-- 管理者権限での緊急調査用SQL
-- RLS制限を回避するための直接SQL実行

-- 1. まずRLS設定を確認
SELECT schemaname, tablename, rowsecurity as rls_enabled 
FROM pg_tables 
WHERE tablename IN ('users', 'user_daily_profit', 'purchases', 'affiliate_cycle')
ORDER BY tablename;

-- 2. 管理者が存在するかチェック
SELECT * FROM admins WHERE admin_user_id = 'masataka.tak@gmail.com';

-- 3. ユーザー「7A9637」の基本情報（RLS無効化）
SET row_security = OFF;
SELECT * FROM users WHERE user_id = '7A9637';

-- 4. ユーザー「7A9637」の日利記録（RLS無効化）
SELECT * FROM user_daily_profit WHERE user_id = '7A9637' ORDER BY date DESC;

-- 5. ユーザー「7A9637」のNFT購入状況（RLS無効化）
SELECT * FROM purchases WHERE user_id = '7A9637' ORDER BY created_at DESC;

-- 6. ユーザー「7A9637」のサイクル状況（RLS無効化）
SELECT * FROM affiliate_cycle WHERE user_id = '7A9637';

-- 7. ユーザー「2BF53B」の基本情報（RLS無効化）
SELECT * FROM users WHERE user_id = '2BF53B';

-- 8. ユーザー「2BF53B」の日利記録（RLS無効化）
SELECT * FROM user_daily_profit WHERE user_id = '2BF53B' ORDER BY date DESC;

-- 9. ユーザー「2BF53B」のNFT購入状況（RLS無効化）
SELECT * FROM purchases WHERE user_id = '2BF53B' ORDER BY created_at DESC;

-- 10. ユーザー「2BF53B」のサイクル状況（RLS無効化）
SELECT * FROM affiliate_cycle WHERE user_id = '2BF53B';

-- 11. 承認済みユーザー一覧（has_approved_nft=true）
SELECT user_id, email, full_name, total_purchases, has_approved_nft, created_at 
FROM users 
WHERE has_approved_nft = true 
ORDER BY created_at DESC;

-- 12. 最新の日利記録全体（最新20件）
SELECT * FROM user_daily_profit 
ORDER BY date DESC, created_at DESC 
LIMIT 20;

-- 13. 承認済み購入記録（運用開始判定用）
SELECT user_id, created_at, admin_approved, nft_quantity, amount_usd,
       created_at::date as purchase_date,
       (created_at + INTERVAL '15 days')::date as operation_start_date,
       CASE 
           WHEN CURRENT_DATE >= (created_at + INTERVAL '15 days')::date THEN 'STARTED'
           ELSE 'WAITING'
       END as operation_status,
       CURRENT_DATE - (created_at + INTERVAL '15 days')::date as days_since_start
FROM purchases 
WHERE admin_approved = true 
ORDER BY created_at DESC;

-- 14. 最新のシステムログ（日利関連）
SELECT * FROM system_logs 
WHERE operation ILIKE '%yield%' 
   OR operation ILIKE '%profit%' 
   OR operation ILIKE '%batch%'
ORDER BY created_at DESC 
LIMIT 10;

-- RLS再有効化
SET row_security = ON;