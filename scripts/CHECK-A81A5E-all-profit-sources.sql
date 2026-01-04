-- A81A5Eの全ての利益ソースを確認

-- 1. nft_daily_profit（個人日利）- 全期間
SELECT
    date,
    daily_profit,
    phase
FROM nft_daily_profit
WHERE user_id = 'A81A5E'
ORDER BY date;

-- 2. user_referral_profit（紹介報酬）- 日次
SELECT
    date,
    profit_amount,
    referrer_level
FROM user_referral_profit
WHERE user_id = 'A81A5E'
ORDER BY date;

-- 3. monthly_referral_profit（紹介報酬）- 月次
SELECT *
FROM monthly_referral_profit
WHERE user_id = 'A81A5E'
ORDER BY year_month;

-- 4. affiliate_cycle
SELECT *
FROM affiliate_cycle
WHERE user_id = 'A81A5E';

-- 5. user_daily_profit（旧テーブル？）
SELECT *
FROM user_daily_profit
WHERE user_id = 'A81A5E'
ORDER BY date
LIMIT 50;

-- 6. A81A5Eの購入履歴
SELECT *
FROM purchases
WHERE user_id = 'A81A5E';

-- 7. A81A5EのNFTの日利履歴（nft_idで検索）
SELECT
    ndp.date,
    ndp.daily_profit,
    ndp.phase,
    nm.nft_type,
    nm.acquired_date
FROM nft_daily_profit ndp
JOIN nft_master nm ON ndp.nft_id = nm.id
WHERE nm.user_id = 'A81A5E'
ORDER BY ndp.date;
