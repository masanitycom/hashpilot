-- NFT価格を1000ドルに統一し、既存データを修正

-- 1. 既存の購入データを1000ドル単位に修正
UPDATE purchases 
SET amount_usd = FLOOR(amount_usd / 1000) * 1000
WHERE amount_usd > 0;

-- 2. システム設定でNFT価格を1000ドルに設定
INSERT INTO system_config (key, value, description) VALUES
('nft_base_price', '1000', 'NFT基本価格（運用額）'),
('nft_total_price', '1100', 'NFT総支払額（手数料込み）'),
('nft_fee', '100', 'NFT購入手数料')
ON CONFLICT (key) DO UPDATE SET 
value = EXCLUDED.value,
updated_at = NOW();

-- 3. ユーザーの投資額も1000ドル単位に修正
UPDATE users 
SET total_purchases = FLOOR(total_purchases / 1000) * 1000
WHERE total_purchases > 0;

-- 4. 紹介報酬計算も1000ドル単位ベースに修正
UPDATE monthly_rewards 
SET reward_amount = FLOOR(reward_amount / 1000) * 1000
WHERE reward_amount > 0;

-- 5. NFT保有テーブルも1000ドル単位に修正
UPDATE nft_holdings 
SET purchase_amount = 1000.00
WHERE purchase_amount != 1000.00;

-- 6. 日次利益計算も1000ドル単位ベースに修正
CREATE OR REPLACE FUNCTION calculate_daily_profit_1000_base()
RETURNS TABLE(
    user_id TEXT,
    date DATE,
    investment_amount DECIMAL(10,2),
    daily_yield_rate DECIMAL(5,4),
    daily_profit DECIMAL(10,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.user_id,
        CURRENT_DATE as date,
        (COALESCE(p.total_investment, 0))::DECIMAL(10,2) as investment_amount,
        COALESCE(dyl.user_rate, 0.0150)::DECIMAL(5,4) as daily_yield_rate,
        (COALESCE(p.total_investment, 0) * COALESCE(dyl.user_rate, 0.0150))::DECIMAL(10,2) as daily_profit
    FROM users u
    LEFT JOIN (
        SELECT 
            user_id,
            SUM(FLOOR(amount_usd / 1000) * 1000) as total_investment
        FROM purchases 
        WHERE admin_approved = true
        GROUP BY user_id
    ) p ON u.user_id = p.user_id
    LEFT JOIN daily_yield_log dyl ON dyl.date = CURRENT_DATE
    WHERE COALESCE(p.total_investment, 0) > 0;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION calculate_daily_profit_1000_base() IS '1000ドル単位ベースでの日次利益計算';
