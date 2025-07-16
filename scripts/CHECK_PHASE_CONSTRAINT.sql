-- 🔍 phase制約の確認
-- 2025年7月17日

-- 1. user_daily_profitテーブルの制約確認
SELECT 
    'テーブル制約確認' as check_type,
    constraint_name,
    constraint_type,
    check_clause
FROM information_schema.table_constraints tc
JOIN information_schema.check_constraints cc ON tc.constraint_name = cc.constraint_name
WHERE tc.table_name = 'user_daily_profit'
AND tc.constraint_type = 'CHECK';

-- 2. 現在のphase値を確認
SELECT 
    'phase値確認' as check_type,
    phase,
    COUNT(*) as count
FROM user_daily_profit 
GROUP BY phase
ORDER BY count DESC;

-- 3. テーブル定義確認
SELECT 
    'カラム情報' as check_type,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'user_daily_profit'
AND column_name = 'phase';