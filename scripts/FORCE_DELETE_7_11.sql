-- 🚨 7/11データの強制削除
-- 2025年7月17日

-- 1. 現在の7/11データを確認
SELECT 
    'Before_Delete' as status,
    user_id,
    daily_profit,
    personal_profit,
    referral_profit,
    created_at
FROM user_daily_profit 
WHERE date = '2025-07-11'
ORDER BY user_id;

-- 2. RLSを一時的に無効化して削除
ALTER TABLE user_daily_profit DISABLE ROW LEVEL SECURITY;

-- 3. 強制削除
DELETE FROM user_daily_profit WHERE date = '2025-07-11';

-- 4. RLSを再有効化
ALTER TABLE user_daily_profit ENABLE ROW LEVEL SECURITY;

-- 5. 削除確認
SELECT 
    'After_Delete' as status,
    COUNT(*) as remaining_count
FROM user_daily_profit 
WHERE date = '2025-07-11';

-- 6. 新しい関数で再実行
SELECT * FROM process_daily_yield_with_cycles('2025-07-11'::date, 0.0011, 30, false, false);

-- 7. 最終確認
SELECT 
    'Final_Result' as status,
    user_id,
    daily_profit,
    personal_profit,
    referral_profit,
    phase,
    created_at
FROM user_daily_profit 
WHERE date = '2025-07-11'
ORDER BY daily_profit DESC;