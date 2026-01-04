-- ========================================
-- 59C23Cの1/1利益を確認
-- ========================================

-- 1. nft_daily_profitの1/1レコード
SELECT '=== 59C23Cの1/1 nft_daily_profit ===' as section;
SELECT nft_id, user_id, date, daily_profit
FROM nft_daily_profit
WHERE user_id = '59C23C' AND date = '2026-01-01';

-- 2. 59C23Cの全NFT
SELECT '=== 59C23Cの全NFT ===' as section;
SELECT id, nft_type, acquired_date, buyback_date
FROM nft_master
WHERE user_id = '59C23C'
ORDER BY acquired_date;

-- 3. 59C23Cのユーザー情報
SELECT '=== 59C23Cユーザー情報 ===' as section;
SELECT user_id, operation_start_date, has_approved_nft
FROM users
WHERE user_id = '59C23C';

-- 4. 59C23Cのaffiliate_cycle
SELECT '=== 59C23C affiliate_cycle ===' as section;
SELECT user_id, phase, cum_usdt, available_usdt, auto_nft_count
FROM affiliate_cycle
WHERE user_id = '59C23C';
