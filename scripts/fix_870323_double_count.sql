-- ========================================
-- ユーザー870323のデータ不整合修正
-- 問題: 1NFT購入($1100)が2NFT($2200)として重複カウントされている
-- ========================================

-- 1. 現在の状態を確認（修正前）
SELECT 'BEFORE FIX - Users table' as status;
SELECT user_id, email, total_purchases, has_approved_nft 
FROM users 
WHERE user_id = '870323';

SELECT 'BEFORE FIX - Affiliate Cycle table' as status;
SELECT user_id, total_nft_count, manual_nft_count, auto_nft_count 
FROM affiliate_cycle 
WHERE user_id = '870323';

SELECT 'BEFORE FIX - Purchases table' as status;
SELECT id, user_id, nft_quantity, amount_usd, admin_approved, payment_status, created_at
FROM purchases 
WHERE user_id = '870323'
ORDER BY created_at DESC;

-- 2. データ修正
-- usersテーブルのtotal_purchasesを正しい値に修正
UPDATE users 
SET total_purchases = 1100,
    updated_at = NOW()
WHERE user_id = '870323';

-- affiliate_cycleテーブルのNFT数を正しい値に修正
UPDATE affiliate_cycle 
SET total_nft_count = 1,
    manual_nft_count = 1,
    auto_nft_count = 0,
    updated_at = NOW()
WHERE user_id = '870323';

-- 3. 修正後の確認
SELECT 'AFTER FIX - Users table' as status;
SELECT user_id, email, total_purchases, has_approved_nft 
FROM users 
WHERE user_id = '870323';

SELECT 'AFTER FIX - Affiliate Cycle table' as status;
SELECT user_id, total_nft_count, manual_nft_count, auto_nft_count 
FROM affiliate_cycle 
WHERE user_id = '870323';

-- 4. 他の影響を受ける可能性があるユーザーをチェック
SELECT 'Checking for similar issues' as status;
SELECT u.user_id, u.email, u.total_purchases, 
       ac.total_nft_count, ac.manual_nft_count,
       COALESCE(p.total_amount, 0) as actual_purchase_amount,
       COALESCE(p.nft_count, 0) as actual_nft_count
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
LEFT JOIN (
    SELECT user_id, 
           SUM(amount_usd) as total_amount,
           SUM(nft_quantity) as nft_count
    FROM purchases
    WHERE admin_approved = true
    GROUP BY user_id
) p ON u.user_id = p.user_id
WHERE u.has_approved_nft = true
  AND (u.total_purchases != COALESCE(p.total_amount, 0) 
       OR ac.total_nft_count != COALESCE(p.nft_count, 0))
ORDER BY u.user_id;

-- 5. 利益計算への影響を確認
SELECT 'Checking profit records' as status;
SELECT * FROM user_daily_profit 
WHERE user_id = '870323' 
ORDER BY date DESC 
LIMIT 10;

SELECT 'Fix completed for user 870323' as status;