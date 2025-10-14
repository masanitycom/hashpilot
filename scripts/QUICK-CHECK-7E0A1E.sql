-- 7E0A1Eの現状を一発確認

-- NFT数
SELECT '7E0A1E: NFT数' as check_point, total_nft_count FROM affiliate_cycle WHERE user_id = '7E0A1E';

-- 日利データ件数
SELECT '7E0A1E: 日利データ' as check_point, COUNT(*) as records FROM nft_daily_profit WHERE user_id = '7E0A1E';

-- 運用開始日
SELECT '7E0A1E: 運用開始日' as check_point, operation_start_date FROM users WHERE user_id = '7E0A1E';

-- 今月の個人利益合計
SELECT '7E0A1E: 今月の個人利益' as check_point, SUM(daily_profit) as total FROM nft_daily_profit WHERE user_id = '7E0A1E' AND date >= '2025-10-01';
