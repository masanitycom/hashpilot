-- NFT価格を1000ドル単位に統一（手数料込み1100ドル）

-- 1. システム設定を更新
UPDATE system_config 
SET value = '1000' 
WHERE key = 'nft_base_price';

INSERT INTO system_config (key, value, description) VALUES
('nft_base_price', '1000', 'NFT基本価格（運用額）'),
('nft_fee_amount', '100', 'NFT購入手数料'),
('nft_total_price', '1100', 'NFT総支払額（基本価格+手数料）')
ON CONFLICT (key) DO UPDATE SET 
value = EXCLUDED.value,
description = EXCLUDED.description;

-- 2. 既存の購入データを更新（1100ドルのものを1000ドル運用+100ドル手数料に分離）
UPDATE purchases 
SET 
    investment_amount = 1000,
    fee_amount = 100
WHERE amount_usd = 1100;

-- 3. NFT保有テーブルの価格を更新
UPDATE nft_holdings 
SET purchase_amount = 1000.00
WHERE purchase_amount = 1100.00;

-- 4. アフィリエイトサイクルテーブルの投資額を更新
UPDATE affiliate_cycle 
SET 
    total_nft_count = COALESCE((
        SELECT COUNT(*) 
        FROM purchases 
        WHERE user_id = affiliate_cycle.user_id 
        AND admin_approved = true
    ), 0),
    manual_nft_count = COALESCE((
        SELECT COUNT(*) 
        FROM purchases 
        WHERE user_id = affiliate_cycle.user_id 
        AND admin_approved = true
    ), 0);

-- 5. 日利計算を1000ドルベースに更新
UPDATE user_daily_profit 
SET daily_profit = (daily_profit / 1100) * 1000
WHERE daily_profit > 0;

-- 6. 紹介報酬計算を1000ドルベースに更新  
UPDATE user_daily_profit 
SET affiliate_rewards = (affiliate_rewards / 1100) * 1000
WHERE affiliate_rewards > 0;

-- 7. 月次報酬テーブルが存在する場合は更新（存在チェック付き）
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_monthly_rewards') THEN
        UPDATE user_monthly_rewards 
        SET 
            daily_profit_total = (daily_profit_total / 1100) * 1000,
            affiliate_rewards = (affiliate_rewards / 1100) * 1000,
            total_amount = (total_amount / 1100) * 1000
        WHERE daily_profit_total > 0 OR affiliate_rewards > 0 OR total_amount > 0;
    END IF;
END $$;

-- 8. 統計情報を更新
COMMENT ON TABLE purchases IS 'NFT購入記録 - 運用額$1000 + 手数料$100 = 総額$1100';
COMMENT ON COLUMN purchases.amount_usd IS '総支払額（$1100）';
COMMENT ON COLUMN purchases.investment_amount IS '実際の運用投資額（$1000）';
COMMENT ON COLUMN purchases.fee_amount IS '手数料（$100）';

-- 確認クエリ
SELECT 
    'システム設定' as category,
    key,
    value,
    description
FROM system_config 
WHERE key IN ('nft_base_price', 'nft_fee_amount', 'nft_total_price')

UNION ALL

SELECT 
    '購入統計' as category,
    'total_purchases' as key,
    COUNT(*)::text as value,
    'NFT購入総数' as description
FROM purchases

UNION ALL

SELECT 
    '投資額統計' as category,
    'total_investment' as key,
    COALESCE(SUM(investment_amount), 0)::text as value,
    '総運用投資額（$1000単位）' as description
FROM purchases
WHERE admin_approved = true;
