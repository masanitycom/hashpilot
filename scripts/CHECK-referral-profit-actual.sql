-- 紹介報酬の実データを確認

SELECT '【11/1の紹介報酬】0件のはず' as info;
SELECT COUNT(*) as count, COALESCE(SUM(profit_amount), 0) as total_amount
FROM user_referral_profit
WHERE date = '2025-11-01';

SELECT '【11/1の紹介報酬詳細】もし残っていたら表示' as info;
SELECT user_id, child_user_id, referral_level, profit_amount, created_at
FROM user_referral_profit
WHERE date = '2025-11-01'
LIMIT 10;

SELECT '【11/1の個人利益】マイナス値が入っているはず' as info;
SELECT COUNT(*) as count, SUM(daily_profit) as total_profit
FROM nft_daily_profit
WHERE date = '2025-11-01';

SELECT '【affiliate_cycleのcum_usdt確認】' as info;
SELECT user_id, cum_usdt, available_usdt
FROM affiliate_cycle
WHERE cum_usdt != 0 OR available_usdt != 0
ORDER BY cum_usdt DESC
LIMIT 10;
