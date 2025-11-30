-- ペガサス特例3名の日利を直接INSERTするスクリプト
-- 実行環境: 本番Supabase
-- 対象: balance.p.p.p.p.1060@gmail.com, akihiro.y.grant@gmail.com, feel.me.yurie@gmail.com
-- 期間: 2025-11-01 以降の全日利

-- =====================================
-- STEP 1: 前提条件の確認
-- =====================================

-- 1-1: 3名のユーザー情報とNFT数を確認
SELECT
    u.user_id,
    u.email,
    u.is_pegasus_exchange,
    u.exclude_from_daily_profit,
    u.operation_start_date,
    COUNT(nm.id) as nft_count,
    ARRAY_AGG(nm.id ORDER BY nm.id) as nft_ids
FROM users u
LEFT JOIN nft_master nm ON u.user_id = nm.user_id AND nm.buyback_date IS NULL
WHERE u.email IN (
    'balance.p.p.p.p.1060@gmail.com',
    'akihiro.y.grant@gmail.com',
    'feel.me.yurie@gmail.com'
)
GROUP BY u.user_id, u.email, u.is_pegasus_exchange, u.exclude_from_daily_profit, u.operation_start_date;

-- 1-2: 2025-11-01以降の日利履歴を確認
SELECT
    date,
    yield_rate,
    margin_rate,
    user_rate,
    ROUND((1000.0 * (yield_rate / 100.0)) * (1.0 - margin_rate) * 0.6, 3) as profit_per_nft
FROM daily_yield_log
WHERE date >= '2025-11-01'
ORDER BY date ASC;

-- =====================================
-- STEP 2: nft_daily_profit に直接INSERT
-- =====================================

-- ⚠️ 前提: ADD-exclude-from-daily-profit-flag.sql が実行済みであること

-- 各ユーザーのNFTごとに、各日付の日利レコードを作成
INSERT INTO nft_daily_profit (nft_id, user_id, date, daily_profit, phase, created_at)
SELECT
    nm.id as nft_id,
    u.user_id,
    dyl.date,
    ROUND((1000.0 * (dyl.yield_rate / 100.0)) * (1.0 - dyl.margin_rate) * 0.6, 3) as daily_profit,
    'USDT' as phase,
    NOW() as created_at
FROM users u
CROSS JOIN daily_yield_log dyl
INNER JOIN nft_master nm ON u.user_id = nm.user_id
WHERE u.email IN (
    'balance.p.p.p.p.1060@gmail.com',
    'akihiro.y.grant@gmail.com',
    'feel.me.yurie@gmail.com'
)
AND dyl.date >= '2025-11-01'
AND nm.buyback_date IS NULL
AND u.operation_start_date IS NOT NULL
AND u.operation_start_date <= dyl.date
-- 重複を防ぐ（既にレコードが存在する場合はスキップ）
AND NOT EXISTS (
    SELECT 1 FROM nft_daily_profit ndp
    WHERE ndp.nft_id = nm.id
    AND ndp.date = dyl.date
);

-- =====================================
-- STEP 3: affiliate_cycle の available_usdt を更新
-- =====================================

-- 各ユーザーの個人利益合計を計算して available_usdt に加算
UPDATE affiliate_cycle ac
SET
    available_usdt = available_usdt + COALESCE((
        SELECT SUM(ndp.daily_profit)
        FROM nft_daily_profit ndp
        WHERE ndp.user_id = ac.user_id
        AND ndp.date >= '2025-11-01'
    ), 0),
    updated_at = NOW()
WHERE ac.user_id IN (
    SELECT user_id FROM users
    WHERE email IN (
        'balance.p.p.p.p.1060@gmail.com',
        'akihiro.y.grant@gmail.com',
        'feel.me.yurie@gmail.com'
    )
);

-- =====================================
-- STEP 4: 紹介報酬の計算・配布
-- =====================================

-- ⚠️ 注意: 紹介報酬は複雑なロジックのため、RPC関数での再計算が必要
-- 以下は簡易版（Level 1のみ）

-- 特例3名が誰かの子会員の場合、その紹介者に報酬を配布
INSERT INTO user_referral_profit (user_id, date, referral_level, child_user_id, profit_amount, created_at)
SELECT
    u_parent.user_id as user_id,
    dyl.date,
    1 as referral_level,
    u_child.user_id as child_user_id,
    ROUND((1000.0 * (dyl.yield_rate / 100.0)) * (1.0 - dyl.margin_rate) * 0.6, 3) * nft_count.cnt * 0.20 as profit_amount,
    NOW() as created_at
FROM users u_child
CROSS JOIN daily_yield_log dyl
INNER JOIN users u_parent ON u_child.referrer_user_id = u_parent.user_id
INNER JOIN (
    SELECT user_id, COUNT(*) as cnt
    FROM nft_master
    WHERE buyback_date IS NULL
    GROUP BY user_id
) nft_count ON u_child.user_id = nft_count.user_id
WHERE u_child.email IN (
    'balance.p.p.p.p.1060@gmail.com',
    'akihiro.y.grant@gmail.com',
    'feel.me.yurie@gmail.com'
)
AND dyl.date >= '2025-11-01'
AND u_parent.operation_start_date IS NOT NULL
AND u_parent.operation_start_date <= dyl.date
-- 重複を防ぐ
AND NOT EXISTS (
    SELECT 1 FROM user_referral_profit urp
    WHERE urp.user_id = u_parent.user_id
    AND urp.date = dyl.date
    AND urp.referral_level = 1
    AND urp.child_user_id = u_child.user_id
);

-- 紹介報酬を affiliate_cycle に反映
UPDATE affiliate_cycle ac
SET
    cum_usdt = cum_usdt + COALESCE((
        SELECT SUM(urp.profit_amount)
        FROM user_referral_profit urp
        WHERE urp.user_id = ac.user_id
        AND urp.date >= '2025-11-01'
        AND urp.child_user_id IN (
            SELECT user_id FROM users
            WHERE email IN (
                'balance.p.p.p.p.1060@gmail.com',
                'akihiro.y.grant@gmail.com',
                'feel.me.yurie@gmail.com'
            )
        )
    ), 0),
    available_usdt = available_usdt + COALESCE((
        SELECT SUM(urp.profit_amount)
        FROM user_referral_profit urp
        WHERE urp.user_id = ac.user_id
        AND urp.date >= '2025-11-01'
        AND urp.child_user_id IN (
            SELECT user_id FROM users
            WHERE email IN (
                'balance.p.p.p.p.1060@gmail.com',
                'akihiro.y.grant@gmail.com',
                'feel.me.yurie@gmail.com'
            )
        )
    ), 0),
    updated_at = NOW()
WHERE EXISTS (
    SELECT 1 FROM user_referral_profit urp
    WHERE urp.user_id = ac.user_id
    AND urp.date >= '2025-11-01'
    AND urp.child_user_id IN (
        SELECT user_id FROM users
        WHERE email IN (
            'balance.p.p.p.p.1060@gmail.com',
            'akihiro.y.grant@gmail.com',
            'feel.me.yurie@gmail.com'
        )
    )
);

-- =====================================
-- STEP 5: 検証
-- =====================================

-- 5-1: 特例3名の日利レコード数確認
SELECT
    u.user_id,
    u.email,
    COUNT(DISTINCT ndp.date) as profit_days,
    COUNT(ndp.id) as profit_records,
    COALESCE(SUM(ndp.daily_profit), 0) as total_personal_profit
FROM users u
LEFT JOIN nft_daily_profit ndp ON u.user_id = ndp.user_id AND ndp.date >= '2025-11-01'
WHERE u.email IN (
    'balance.p.p.p.p.1060@gmail.com',
    'akihiro.y.grant@gmail.com',
    'feel.me.yurie@gmail.com'
)
GROUP BY u.user_id, u.email
ORDER BY u.email;

-- 5-2: affiliate_cycle の更新確認
SELECT
    u.user_id,
    u.email,
    ac.available_usdt,
    ac.cum_usdt
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE u.email IN (
    'balance.p.p.p.p.1060@gmail.com',
    'akihiro.y.grant@gmail.com',
    'feel.me.yurie@gmail.com'
)
ORDER BY u.email;

-- 5-3: 日付別の日利確認（1名のみサンプル）
SELECT
    ndp.date,
    COUNT(*) as nft_count,
    SUM(ndp.daily_profit) as daily_total
FROM nft_daily_profit ndp
INNER JOIN users u ON ndp.user_id = u.user_id
WHERE u.email = 'balance.p.p.p.p.1060@gmail.com'
AND ndp.date >= '2025-11-01'
GROUP BY ndp.date
ORDER BY ndp.date ASC;
