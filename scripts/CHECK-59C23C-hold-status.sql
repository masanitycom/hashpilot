-- ========================================
-- ユーザー 59C23C のHOLD状態調査
-- ========================================

-- 1. 基本情報
SELECT '=== 1. ユーザー基本情報 ===' as section;
SELECT
    user_id,
    email,
    full_name,
    has_approved_nft,
    operation_start_date,
    is_pegasus_exchange,
    created_at
FROM users
WHERE user_id = '59C23C';

-- 2. affiliate_cycle状態
SELECT '=== 2. affiliate_cycle状態 ===' as section;
SELECT
    user_id,
    cum_usdt,
    available_usdt,
    phase,
    auto_nft_count,
    manual_nft_count,
    withdrawn_referral_usdt,
    updated_at
FROM affiliate_cycle
WHERE user_id = '59C23C';

-- 3. NFT保有状況
SELECT '=== 3. NFT保有状況（nft_master） ===' as section;
SELECT
    id,
    nft_type,
    acquired_date,
    buyback_date,
    created_at
FROM nft_master
WHERE user_id = '59C23C'
ORDER BY acquired_date;

-- 4. 購入履歴
SELECT '=== 4. 購入履歴（purchases） ===' as section;
SELECT
    id,
    amount_usd,
    admin_approved,
    is_auto_purchase,
    cycle_number_at_purchase,
    created_at
FROM purchases
WHERE user_id = '59C23C'
ORDER BY created_at;

-- 5. 紹介報酬合計（月次）
SELECT '=== 5. 紹介報酬合計（user_referral_profit_monthly） ===' as section;
SELECT
    year,
    month,
    referral_level,
    SUM(profit_amount) as total_profit,
    COUNT(*) as record_count
FROM user_referral_profit_monthly
WHERE user_id = '59C23C'
GROUP BY year, month, referral_level
ORDER BY year DESC, month DESC, referral_level;

-- 6. 紹介報酬総合計
SELECT '=== 6. 紹介報酬総合計 ===' as section;
SELECT
    SUM(profit_amount) as total_referral_profit
FROM user_referral_profit_monthly
WHERE user_id = '59C23C';

-- 7. 個人利益合計
SELECT '=== 7. 個人利益合計（user_daily_profit） ===' as section;
SELECT
    SUM(daily_profit) as total_personal_profit,
    COUNT(*) as days
FROM user_daily_profit
WHERE user_id = '59C23C';

-- 8. HOLD状態の確認
SELECT '=== 8. HOLD状態分析 ===' as section;
SELECT
    ac.cum_usdt,
    ac.phase,
    CASE
        WHEN ac.cum_usdt >= 2200 THEN 'NFT自動付与対象（$2,200以上）'
        WHEN ac.cum_usdt >= 1100 THEN 'HOLDフェーズ（$1,100-$2,199）'
        ELSE 'USDTフェーズ（$0-$1,099）'
    END as status_description,
    ac.cum_usdt - 1100 as remaining_to_nft,
    ac.auto_nft_count as auto_nft_granted
FROM affiliate_cycle ac
WHERE ac.user_id = '59C23C';
