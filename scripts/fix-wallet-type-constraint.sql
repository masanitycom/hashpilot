-- wallet_type制約を修正（USDT BEP20とCoinWのみ許可）

-- 1. 既存の制約を削除
ALTER TABLE buyback_requests DROP CONSTRAINT IF EXISTS buyback_requests_wallet_type_check;

-- 2. 新しい制約を追加
ALTER TABLE buyback_requests ADD CONSTRAINT buyback_requests_wallet_type_check 
CHECK (wallet_type IN ('USDT-BEP20', 'CoinW'));

-- 3. create_buyback_request関数も確認して必要なら更新
-- 関数内でwallet_typeのバリデーションをしている場合は、そこも修正が必要

-- 4. 確認
SELECT 
    constraint_name,
    check_clause
FROM information_schema.check_constraints
WHERE constraint_name = 'buyback_requests_wallet_type_check';