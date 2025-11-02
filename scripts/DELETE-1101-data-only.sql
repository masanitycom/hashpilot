-- 11/1のデータを削除するだけ（再計算はしない）

-- ===== 削除前の確認 =====
SELECT '【削除前】daily_yield_log' as info;
SELECT * FROM daily_yield_log WHERE date = '2025-11-01';

SELECT '【削除前】nft_daily_profit（件数）' as info;
SELECT COUNT(*) as count FROM nft_daily_profit WHERE date = '2025-11-01';

SELECT '【削除前】user_referral_profit（件数）' as info;
SELECT COUNT(*) as count FROM user_referral_profit WHERE date = '2025-11-01';

-- ===== 削除実行 =====
DELETE FROM user_referral_profit WHERE date = '2025-11-01';
DELETE FROM nft_daily_profit WHERE date = '2025-11-01';
DELETE FROM daily_yield_log WHERE date = '2025-11-01';

-- ===== 削除後の確認 =====
SELECT '【削除完了】daily_yield_log' as info;
SELECT COUNT(*) as count FROM daily_yield_log WHERE date = '2025-11-01';

SELECT '【削除完了】nft_daily_profit' as info;
SELECT COUNT(*) as count FROM nft_daily_profit WHERE date = '2025-11-01';

SELECT '【削除完了】user_referral_profit' as info;
SELECT COUNT(*) as count FROM user_referral_profit WHERE date = '2025-11-01';

SELECT '✅ 11/1のデータを全て削除しました' as result;
