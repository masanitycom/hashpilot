-- ========================================
-- テストユーザー削除スクリプト
-- ========================================
-- 対象: 7E0A1E, 633DF2, 6D9503, 897F27

-- 1. 削除前の確認
SELECT
    '削除前: ユーザー情報' as section,
    user_id,
    email,
    full_name,
    created_at,
    has_approved_nft,
    total_purchases
FROM users
WHERE user_id IN ('7E0A1E', '633DF2', '6D9503', '897F27')
ORDER BY user_id;

-- 2. 各ユーザーのNFT数を確認
SELECT
    '削除前: NFT数' as section,
    user_id,
    COUNT(*) as total_nft,
    COUNT(*) FILTER (WHERE nft_type = 'manual') as manual_nft,
    COUNT(*) FILTER (WHERE nft_type = 'auto') as auto_nft,
    COUNT(*) FILTER (WHERE buyback_date IS NULL) as active_nft
FROM nft_master
WHERE user_id IN ('7E0A1E', '633DF2', '6D9503', '897F27')
GROUP BY user_id
ORDER BY user_id;

-- 3. 購入レコード確認
SELECT
    '削除前: 購入レコード' as section,
    user_id,
    COUNT(*) as purchase_count,
    SUM(amount_usd) as total_amount
FROM purchases
WHERE user_id IN ('7E0A1E', '633DF2', '6D9503', '897F27')
GROUP BY user_id
ORDER BY user_id;

-- ========================================
-- 削除実行
-- ========================================

-- 4. nft_daily_profit から削除
DELETE FROM nft_daily_profit
WHERE user_id IN ('7E0A1E', '633DF2', '6D9503', '897F27');

-- 5. nft_master から削除
DELETE FROM nft_master
WHERE user_id IN ('7E0A1E', '633DF2', '6D9503', '897F27');

-- 6. purchases から削除
DELETE FROM purchases
WHERE user_id IN ('7E0A1E', '633DF2', '6D9503', '897F27');

-- 7. buyback_requests から削除
DELETE FROM buyback_requests
WHERE user_id IN ('7E0A1E', '633DF2', '6D9503', '897F27');

-- 8. monthly_withdrawals から削除
DELETE FROM monthly_withdrawals
WHERE user_id IN ('7E0A1E', '633DF2', '6D9503', '897F27');

-- 9. affiliate_cycle から削除
DELETE FROM affiliate_cycle
WHERE user_id IN ('7E0A1E', '633DF2', '6D9503', '897F27');

-- 10. email_recipients から削除（システムメール）
DELETE FROM email_recipients
WHERE user_id IN ('7E0A1E', '633DF2', '6D9503', '897F27');

-- 11. monthly_reward_tasks から削除
DELETE FROM monthly_reward_tasks
WHERE user_id IN ('7E0A1E', '633DF2', '6D9503', '897F27');

-- 12. これらのユーザーを紹介者としているユーザーの参照を削除
UPDATE users
SET referrer_user_id = NULL
WHERE referrer_user_id IN ('7E0A1E', '633DF2', '6D9503', '897F27');

-- 13. 最後に users テーブルから削除
DELETE FROM users
WHERE user_id IN ('7E0A1E', '633DF2', '6D9503', '897F27');

-- ========================================
-- 削除後の確認
-- ========================================

-- 14. 削除されたか確認
SELECT
    '削除後: ユーザー確認' as section,
    COUNT(*) as remaining_users
FROM users
WHERE user_id IN ('7E0A1E', '633DF2', '6D9503', '897F27');

-- 15. NFTも削除されたか確認
SELECT
    '削除後: NFT確認' as section,
    COUNT(*) as remaining_nft
FROM nft_master
WHERE user_id IN ('7E0A1E', '633DF2', '6D9503', '897F27');

-- 16. 購入レコードも削除されたか確認
SELECT
    '削除後: 購入レコード確認' as section,
    COUNT(*) as remaining_purchases
FROM purchases
WHERE user_id IN ('7E0A1E', '633DF2', '6D9503', '897F27');

-- 17. 全体統計（削除後）
SELECT
    '削除後: 全体統計' as section,
    (SELECT COUNT(*) FROM users) as total_users,
    (SELECT COUNT(*) FROM nft_master WHERE buyback_date IS NULL) as total_active_nft,
    (SELECT COUNT(*) FROM purchases WHERE admin_approved = true) as total_approved_purchases;

-- 完了メッセージ
SELECT '✅ テストユーザー4人を完全に削除しました' as status;
