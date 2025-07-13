-- 出金関連テーブルの構造確認
-- 正しいカラム名を特定してからクリーンアップ

-- ========================================
-- 1. 出金関連テーブルの構造を確認
-- ========================================

-- monthly_withdrawalsテーブルの構造
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'monthly_withdrawals' 
    AND table_schema = 'public'
ORDER BY ordinal_position;

-- user_withdrawal_settingsテーブルの構造
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'user_withdrawal_settings' 
    AND table_schema = 'public'
ORDER BY ordinal_position;

-- buyback_requestsテーブルの構造
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'buyback_requests' 
    AND table_schema = 'public'
ORDER BY ordinal_position;

-- ========================================
-- 2. 各テーブルの実際のデータを確認
-- ========================================

-- monthly_withdrawalsの現在のデータ（最初の5件）
SELECT * FROM monthly_withdrawals LIMIT 5;

-- user_withdrawal_settingsの現在のデータ（最初の5件）
SELECT * FROM user_withdrawal_settings LIMIT 5;

-- buyback_requestsの現在のデータ（最初の5件）
SELECT * FROM buyback_requests LIMIT 5;

-- ========================================
-- 3. ダッシュボードで$88.08が表示される可能性のあるデータ検索
-- ========================================

-- 88.08という値を持つレコードを全テーブルから検索
-- monthly_withdrawals
SELECT 
    'monthly_withdrawals' as table_name,
    *
FROM monthly_withdrawals 
WHERE CAST(COALESCE(withdrawal_amount, requested_amount, total_amount, 0) as TEXT) LIKE '%88.08%'
   OR CAST(COALESCE(withdrawal_amount, requested_amount, total_amount, 0) as NUMERIC) = 88.08;

-- user_withdrawal_settings  
SELECT 
    'user_withdrawal_settings' as table_name,
    *
FROM user_withdrawal_settings 
WHERE CAST(COALESCE(pending_amount, available_amount, balance, 0) as TEXT) LIKE '%88.08%'
   OR CAST(COALESCE(pending_amount, available_amount, balance, 0) as NUMERIC) = 88.08;

-- buyback_requests
SELECT 
    'buyback_requests' as table_name,
    *
FROM buyback_requests 
WHERE CAST(COALESCE(total_buyback_amount, buyback_amount, amount, 0) as TEXT) LIKE '%88.08%'
   OR CAST(COALESCE(total_buyback_amount, buyback_amount, amount, 0) as NUMERIC) = 88.08;

-- affiliate_cycleからも確認
SELECT 
    'affiliate_cycle' as table_name,
    user_id,
    available_usdt,
    cum_usdt
FROM affiliate_cycle 
WHERE CAST(available_usdt as TEXT) LIKE '%88.08%' 
   OR CAST(cum_usdt as TEXT) LIKE '%88.08%'
   OR available_usdt = 88.08 
   OR cum_usdt = 88.08;

-- ========================================
-- 4. 88.08に近い値も検索（88.00-89.00の範囲）
-- ========================================

-- affiliate_cycleで88ドル前後の値
SELECT 
    'affiliate_cycle_88range' as search_type,
    user_id,
    available_usdt,
    cum_usdt,
    total_nft_count
FROM affiliate_cycle 
WHERE available_usdt BETWEEN 88.00 AND 89.00
   OR cum_usdt BETWEEN 88.00 AND 89.00
ORDER BY available_usdt DESC, cum_usdt DESC;

-- monthly_withdrawalsで88ドル前後（カラム名不明のため動的に検索）
-- 最初にテーブル内容を確認
SELECT 
    'monthly_withdrawals_sample' as info,
    COUNT(*) as total_records
FROM monthly_withdrawals;