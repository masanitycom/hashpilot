-- ============================================================
-- テスト環境用のテストデータ作成SQL
-- ============================================================
-- テストプロジェクト: https://supabase.com/dashboard/project/objpuphnhcjxrsiydjbf/sql
-- ============================================================

-- ============================================================
-- STEP 1: 管理者ユーザーを作成
-- ============================================================

INSERT INTO admins (user_id, email, role, is_active)
VALUES
    ('admin1', 'admin@test.com', 'admin', true)
ON CONFLICT (email) DO NOTHING;

-- ============================================================
-- STEP 2: テスト用通常ユーザーを作成
-- ============================================================

-- 通常ユーザー1（紹介者なし）
INSERT INTO users (
    id,
    user_id,
    email,
    full_name,
    referrer_user_id,
    is_active,
    is_approved,
    total_purchases,
    has_approved_nft,
    operation_start_date,
    is_pegasus_exchange,
    created_at
) VALUES (
    gen_random_uuid(),
    'TEST01',
    'normal-user1@test.com',
    'Normal Test User 1',
    NULL,
    true,
    true,
    1100.00,
    true,
    CURRENT_DATE - INTERVAL '30 days',  -- 30日前から運用開始
    false,
    CURRENT_DATE - INTERVAL '35 days'
);

-- 通常ユーザー2（USER1の紹介）
INSERT INTO users (
    id,
    user_id,
    email,
    full_name,
    referrer_user_id,
    is_active,
    is_approved,
    total_purchases,
    has_approved_nft,
    operation_start_date,
    is_pegasus_exchange,
    created_at
) VALUES (
    gen_random_uuid(),
    'TEST02',
    'normal-user2@test.com',
    'Normal Test User 2',
    'TEST01',
    true,
    true,
    2200.00,  -- NFT 2個
    true,
    CURRENT_DATE - INTERVAL '25 days',
    false,
    CURRENT_DATE - INTERVAL '30 days'
);

-- ============================================================
-- STEP 3: テスト用ペガサスユーザーを作成
-- ============================================================

-- ペガサスユーザー1（通常ユーザーから交換）
INSERT INTO users (
    id,
    user_id,
    email,
    full_name,
    referrer_user_id,
    is_active,
    is_approved,
    total_purchases,
    has_approved_nft,
    operation_start_date,
    is_pegasus_exchange,
    pegasus_exchange_date,
    pegasus_withdrawal_unlock_date,
    created_at
) VALUES (
    gen_random_uuid(),
    'PEGA01',
    'pegasus-user1@test.com',
    'Pegasus Test User 1',
    NULL,
    true,
    true,
    1100.00,
    true,
    CURRENT_DATE - INTERVAL '30 days',
    true,  -- ペガサス交換ユーザー
    CURRENT_DATE - INTERVAL '10 days',  -- 10日前にペガサス交換
    CURRENT_DATE + INTERVAL '350 days', -- 1年後に出金可能
    CURRENT_DATE - INTERVAL '35 days'
);

-- ペガサスユーザー2（USER1の紹介、NFT 2個）
INSERT INTO users (
    id,
    user_id,
    email,
    full_name,
    referrer_user_id,
    is_active,
    is_approved,
    total_purchases,
    has_approved_nft,
    operation_start_date,
    is_pegasus_exchange,
    pegasus_exchange_date,
    pegasus_withdrawal_unlock_date,
    created_at
) VALUES (
    gen_random_uuid(),
    'PEGA02',
    'pegasus-user2@test.com',
    'Pegasus Test User 2',
    'TEST01',  -- TEST01の紹介
    true,
    true,
    2200.00,  -- NFT 2個
    true,
    CURRENT_DATE - INTERVAL '25 days',
    true,  -- ペガサス交換ユーザー
    CURRENT_DATE - INTERVAL '15 days',
    CURRENT_DATE + INTERVAL '345 days',
    CURRENT_DATE - INTERVAL '30 days'
);

-- ============================================================
-- STEP 4: affiliate_cycleデータを作成
-- ============================================================

-- 通常ユーザー1
INSERT INTO affiliate_cycle (
    user_id,
    cycle_number,
    phase,
    cum_usdt,
    available_usdt,
    total_nft_count,
    manual_nft_count,
    auto_nft_count
) VALUES (
    'TEST01',
    1,
    'USDT',
    0.00,
    0.00,
    1,  -- NFT 1個
    1,
    0
);

-- 通常ユーザー2
INSERT INTO affiliate_cycle (
    user_id,
    cycle_number,
    phase,
    cum_usdt,
    available_usdt,
    total_nft_count,
    manual_nft_count,
    auto_nft_count
) VALUES (
    'TEST02',
    1,
    'USDT',
    0.00,
    0.00,
    2,  -- NFT 2個
    2,
    0
);

-- ペガサスユーザー1
INSERT INTO affiliate_cycle (
    user_id,
    cycle_number,
    phase,
    cum_usdt,
    available_usdt,
    total_nft_count,
    manual_nft_count,
    auto_nft_count
) VALUES (
    'PEGA01',
    1,
    'USDT',
    0.00,
    0.00,
    1,  -- NFT 1個
    1,
    0
);

-- ペガサスユーザー2
INSERT INTO affiliate_cycle (
    user_id,
    cycle_number,
    phase,
    cum_usdt,
    available_usdt,
    total_nft_count,
    manual_nft_count,
    auto_nft_count
) VALUES (
    'PEGA02',
    1,
    'USDT',
    0.00,
    0.00,
    2,  -- NFT 2個
    2,
    0
);

-- ============================================================
-- STEP 5: purchasesデータを作成（履歴用）
-- ============================================================

INSERT INTO purchases (
    id,
    user_id,
    nft_quantity,
    amount_usd,
    admin_approved,
    admin_approved_at,
    created_at
) VALUES
    (gen_random_uuid(), 'TEST01', 1, 1100.00, true, CURRENT_DATE - INTERVAL '35 days', CURRENT_DATE - INTERVAL '35 days'),
    (gen_random_uuid(), 'TEST02', 2, 2200.00, true, CURRENT_DATE - INTERVAL '30 days', CURRENT_DATE - INTERVAL '30 days'),
    (gen_random_uuid(), 'PEGA01', 1, 1100.00, true, CURRENT_DATE - INTERVAL '35 days', CURRENT_DATE - INTERVAL '35 days'),
    (gen_random_uuid(), 'PEGA02', 2, 2200.00, true, CURRENT_DATE - INTERVAL '30 days', CURRENT_DATE - INTERVAL '30 days');

-- ============================================================
-- 完了
-- ============================================================

-- 確認クエリ
SELECT
    u.user_id,
    u.email,
    u.full_name,
    u.is_pegasus_exchange,
    u.total_purchases,
    ac.total_nft_count,
    u.operation_start_date
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE u.user_id IN ('TEST01', 'TEST02', 'PEGA01', 'PEGA02')
ORDER BY u.user_id;
