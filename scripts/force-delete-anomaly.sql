-- 3000%の異常値データを強制削除するSQL

-- 1. まず該当データを確認
SELECT * FROM daily_yield_log 
WHERE date = '2025-07-10' 
AND margin_rate > 1;

-- 2. バックアップとして保存（必要な場合）
-- CREATE TABLE daily_yield_log_backup AS 
-- SELECT * FROM daily_yield_log WHERE date = '2025-07-10';

-- 3. 強制削除（管理者権限で実行）
DELETE FROM daily_yield_log 
WHERE date = '2025-07-10' 
AND margin_rate > 1;

-- 4. 関連するuser_daily_profitも削除
DELETE FROM user_daily_profit 
WHERE date = '2025-07-10';

-- 5. 削除確認
SELECT COUNT(*) as remaining_count 
FROM daily_yield_log 
WHERE date = '2025-07-10';

-- 6. RLSポリシーの確認（削除が効かない場合）
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename IN ('daily_yield_log', 'user_daily_profit');