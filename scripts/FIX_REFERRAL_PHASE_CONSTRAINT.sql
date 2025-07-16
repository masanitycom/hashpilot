-- 🚨 REFERRAL phase制約の修正
-- 2025年7月17日

-- 1. 現在の制約を確認
SELECT 
    '現在の制約' as check_type,
    cc.constraint_name,
    cc.check_clause
FROM information_schema.check_constraints cc
WHERE cc.constraint_name LIKE '%phase%';

-- 2. 制約を削除（一時的）
ALTER TABLE user_daily_profit DROP CONSTRAINT IF EXISTS user_daily_profit_phase_check;

-- 3. 新しい制約を追加（REFERRALを含む）
ALTER TABLE user_daily_profit 
ADD CONSTRAINT user_daily_profit_phase_check 
CHECK (phase IN ('USDT', 'HOLD', 'REFERRAL'));

-- 4. 制約確認
SELECT 
    '修正後の制約' as check_type,
    cc.constraint_name,
    cc.check_clause
FROM information_schema.check_constraints cc
WHERE cc.constraint_name LIKE '%phase%';