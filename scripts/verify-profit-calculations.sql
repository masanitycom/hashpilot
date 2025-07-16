-- 各ユーザーの正確な利益計算確認（管理者は統計除外）
-- 2025年1月16日作成

-- 管理者を除外した統計で、各ユーザーの正確な利益計算
WITH admin_users AS (
    SELECT user_id FROM admins
),
user_profits AS (
    SELECT 
        u.user_id,
        u.email,
        u.has_approved_nft,
        u.is_active,
        CASE WHEN au.user_id IS NOT NULL THEN true ELSE false END as is_admin,
        -- 個人利益（昨日）
        COALESCE(SUM(CASE WHEN udp.date = CURRENT_DATE - 1 THEN udp.daily_profit ELSE 0 END), 0) as personal_profit_yesterday,
        -- 個人利益（今月累計）
        COALESCE(SUM(CASE WHEN udp.date >= DATE_TRUNC('month', CURRENT_DATE) THEN udp.daily_profit ELSE 0 END), 0) as personal_profit_this_month,
        -- 全期間の個人利益
        COALESCE(SUM(udp.daily_profit), 0) as personal_profit_total,
        -- affiliate_cycleの状況
        ac.cum_usdt,
        ac.available_usdt,
        ac.total_nft_count,
        ac.phase,
        -- 購入情報
        MAX(p.admin_approved_at::date) as latest_approval_date,
        MAX(p.admin_approved_at::date) + INTERVAL '15 days' as operation_start_date,
        -- 運用状況
        CASE 
            WHEN MAX(p.admin_approved_at::date) + INTERVAL '14 days' >= CURRENT_DATE THEN '待機中'
            ELSE '運用中'
        END as operation_status
    FROM users u
    LEFT JOIN admin_users au ON u.user_id = au.user_id
    LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id
    LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
    LEFT JOIN purchases p ON u.user_id = p.user_id AND p.admin_approved = true
    WHERE u.has_approved_nft = true
    GROUP BY u.user_id, u.email, u.has_approved_nft, u.is_active, au.user_id, ac.cum_usdt, ac.available_usdt, ac.total_nft_count, ac.phase
)
SELECT 
    '=== 利益計算確認（管理者は統計除外）===' as title,
    user_id,
    email,
    CASE WHEN is_admin THEN '[管理者]' ELSE '[一般]' END as user_type,
    operation_status,
    latest_approval_date,
    operation_start_date,
    total_nft_count,
    cum_usdt as affiliate_cycle_cum_usdt,
    available_usdt as affiliate_cycle_available_usdt,
    personal_profit_yesterday,
    personal_profit_this_month,
    personal_profit_total,
    phase
FROM user_profits
ORDER BY latest_approval_date DESC;

-- 紹介報酬の計算も確認
WITH referral_profits AS (
    SELECT 
        u.user_id,
        u.email,
        -- Level1紹介者の利益（20%）
        COALESCE(SUM(CASE WHEN ref1.user_id IS NOT NULL THEN udp1.daily_profit * 0.20 ELSE 0 END), 0) as level1_referral_profit,
        -- Level2紹介者の利益（10%）
        COALESCE(SUM(CASE WHEN ref2.user_id IS NOT NULL THEN udp2.daily_profit * 0.10 ELSE 0 END), 0) as level2_referral_profit,
        -- Level3紹介者の利益（5%）
        COALESCE(SUM(CASE WHEN ref3.user_id IS NOT NULL THEN udp3.daily_profit * 0.05 ELSE 0 END), 0) as level3_referral_profit
    FROM users u
    LEFT JOIN users ref1 ON ref1.referrer_user_id = u.user_id
    LEFT JOIN users ref2 ON ref2.referrer_user_id = ref1.user_id
    LEFT JOIN users ref3 ON ref3.referrer_user_id = ref2.user_id
    LEFT JOIN user_daily_profit udp1 ON ref1.user_id = udp1.user_id
    LEFT JOIN user_daily_profit udp2 ON ref2.user_id = udp2.user_id
    LEFT JOIN user_daily_profit udp3 ON ref3.user_id = udp3.user_id
    WHERE u.has_approved_nft = true
    GROUP BY u.user_id, u.email
)
SELECT 
    '=== 紹介報酬計算確認 ===' as title,
    rp.user_id,
    rp.email,
    rp.level1_referral_profit,
    rp.level2_referral_profit,
    rp.level3_referral_profit,
    (rp.level1_referral_profit + rp.level2_referral_profit + rp.level3_referral_profit) as total_referral_profit
FROM referral_profits rp
WHERE (rp.level1_referral_profit + rp.level2_referral_profit + rp.level3_referral_profit) > 0
ORDER BY total_referral_profit DESC;

-- 7A9637の詳細計算確認
SELECT 
    '=== 7A9637の詳細利益計算 ===' as title,
    udp.date,
    udp.daily_profit,
    udp.yield_rate,
    udp.user_rate,
    udp.base_amount,
    udp.phase
FROM user_daily_profit udp
WHERE udp.user_id = '7A9637'
ORDER BY udp.date DESC;