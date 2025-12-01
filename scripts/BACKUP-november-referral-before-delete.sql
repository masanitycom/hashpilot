-- ========================================
-- 11月紹介報酬データのバックアップ
-- ========================================
--
-- 削除前に必ずバックアップを取る
--
-- 実行方法:
-- 1. このクエリを実行
-- 2. 結果をCSVでエクスポート
-- 3. D:\HASHPILOT\Backup に保存
--
-- ファイル名: november-referral-backup-20251201.csv
-- ========================================

-- user_referral_profitテーブルの11月データ全件
SELECT
    user_id,
    date,
    referral_level,
    child_user_id,
    child_daily_profit,
    profit_amount,
    created_at
FROM user_referral_profit
WHERE date >= '2025-11-01' AND date <= '2025-11-30'
ORDER BY date, user_id, referral_level, child_user_id;
