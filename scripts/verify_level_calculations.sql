-- ========================================
-- レベル別人数と投資額の計算検証
-- ========================================

-- テスト用のユーザーIDを設定（必要に応じて変更）
DO $$
DECLARE
    v_user_id VARCHAR(6) := 'B93FFB'; -- 検証したいユーザーID
BEGIN
    -- 結果を格納する一時テーブルを作成
    CREATE TEMP TABLE IF NOT EXISTS level_verification (
        level_num INTEGER,
        user_count INTEGER,
        total_investment DECIMAL,
        user_list TEXT,
        verification_notes TEXT
    );
    
    TRUNCATE level_verification;
END $$;

-- 1. Level1（直接紹介）の検証
WITH level1_users AS (
    SELECT 
        u.user_id,
        u.email,
        u.total_purchases,
        ac.total_nft_count,
        ac.total_nft_count * 1000 as calculated_investment
    FROM users u
    LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
    WHERE u.referrer_user_id = 'B93FFB'  -- 直接紹介者
      AND u.has_approved_nft = true
)
INSERT INTO level_verification (level_num, user_count, total_investment, user_list, verification_notes)
SELECT 
    1 as level_num,
    COUNT(*) as user_count,
    SUM(calculated_investment) as total_investment,
    STRING_AGG(user_id || '(' || email || '): $' || calculated_investment, ', ') as user_list,
    'Level1: 直接紹介者（referrer_user_id = B93FFB）' as verification_notes
FROM level1_users;

-- 2. Level2（間接紹介）の検証
WITH level1_users AS (
    SELECT user_id
    FROM users
    WHERE referrer_user_id = 'B93FFB'
      AND has_approved_nft = true
),
level2_users AS (
    SELECT 
        u.user_id,
        u.email,
        u.total_purchases,
        ac.total_nft_count,
        ac.total_nft_count * 1000 as calculated_investment
    FROM users u
    LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
    WHERE u.referrer_user_id IN (SELECT user_id FROM level1_users)
      AND u.has_approved_nft = true
)
INSERT INTO level_verification (level_num, user_count, total_investment, user_list, verification_notes)
SELECT 
    2 as level_num,
    COUNT(*) as user_count,
    SUM(calculated_investment) as total_investment,
    STRING_AGG(user_id || '(' || email || '): $' || calculated_investment, ', ') as user_list,
    'Level2: Level1ユーザーの紹介者' as verification_notes
FROM level2_users;

-- 3. Level3の検証
WITH level1_users AS (
    SELECT user_id
    FROM users
    WHERE referrer_user_id = 'B93FFB'
      AND has_approved_nft = true
),
level2_users AS (
    SELECT user_id
    FROM users
    WHERE referrer_user_id IN (SELECT user_id FROM level1_users)
      AND has_approved_nft = true
),
level3_users AS (
    SELECT 
        u.user_id,
        u.email,
        u.total_purchases,
        ac.total_nft_count,
        ac.total_nft_count * 1000 as calculated_investment
    FROM users u
    LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
    WHERE u.referrer_user_id IN (SELECT user_id FROM level2_users)
      AND u.has_approved_nft = true
)
INSERT INTO level_verification (level_num, user_count, total_investment, user_list, verification_notes)
SELECT 
    3 as level_num,
    COUNT(*) as user_count,
    SUM(calculated_investment) as total_investment,
    STRING_AGG(user_id || '(' || email || '): $' || calculated_investment, ', ') as user_list,
    'Level3: Level2ユーザーの紹介者' as verification_notes
FROM level3_users;

-- 4. Level4以降の検証
WITH RECURSIVE referral_chain AS (
    -- Level1
    SELECT user_id, 1 as level
    FROM users
    WHERE referrer_user_id = 'B93FFB'
      AND has_approved_nft = true
    
    UNION ALL
    
    -- 再帰的にLevel2以降を取得
    SELECT u.user_id, rc.level + 1
    FROM users u
    INNER JOIN referral_chain rc ON u.referrer_user_id = rc.user_id
    WHERE u.has_approved_nft = true
      AND rc.level < 10  -- 最大10レベルまで
),
level4_plus_users AS (
    SELECT 
        u.user_id,
        u.email,
        rc.level,
        ac.total_nft_count,
        ac.total_nft_count * 1000 as calculated_investment
    FROM referral_chain rc
    JOIN users u ON rc.user_id = u.user_id
    LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
    WHERE rc.level >= 4
)
INSERT INTO level_verification (level_num, user_count, total_investment, user_list, verification_notes)
SELECT 
    4 as level_num,
    COUNT(*) as user_count,
    SUM(calculated_investment) as total_investment,
    STRING_AGG('L' || level || ':' || user_id || '(' || email || '): $' || calculated_investment, ', ' ORDER BY level, user_id) as user_list,
    'Level4以降: Level3ユーザーの紹介者以降' as verification_notes
FROM level4_plus_users;

-- 5. 結果の表示
SELECT 
    'Level' || level_num as level,
    user_count as "人数",
    total_investment as "投資額合計",
    CASE level_num
        WHEN 1 THEN '20%'
        WHEN 2 THEN '10%'
        WHEN 3 THEN '5%'
        ELSE '0%'
    END as "報酬率",
    total_investment * 
    CASE level_num
        WHEN 1 THEN 0.002  -- 日利0.1% × 20%
        WHEN 2 THEN 0.001  -- 日利0.1% × 10%
        WHEN 3 THEN 0.0005 -- 日利0.1% × 5%
        ELSE 0
    END as "1日の紹介報酬",
    verification_notes as "検証メモ"
FROM level_verification
ORDER BY level_num;

-- 6. 詳細なユーザーリスト
SELECT 
    'Level' || level_num as level,
    user_list as "ユーザー詳細"
FROM level_verification
WHERE user_list IS NOT NULL
ORDER BY level_num;

-- 7. 計算式の確認
SELECT 
    '=== 計算式の確認 ===' as title,
    '投資額 = NFT数 × $1,000' as formula1,
    'NFT数 = total_purchases ÷ $1,100（端数切り捨て）' as formula2,
    'Level1報酬 = Level1投資額合計 × 日利 × 20%' as formula3,
    'Level2報酬 = Level2投資額合計 × 日利 × 10%' as formula4,
    'Level3報酬 = Level3投資額合計 × 日利 × 5%' as formula5,
    'Level4以降報酬 = 0%（報酬なし）' as formula6;

-- 8. 現在のダッシュボード表示値との比較（該当ユーザーの実際の統計）
SELECT 
    '=== ダッシュボード表示値との比較 ===' as title,
    user_id,
    email,
    'Direct Referrals' as metric,
    (SELECT COUNT(*) FROM users WHERE referrer_user_id = 'B93FFB' AND has_approved_nft = true) as value
FROM users 
WHERE user_id = 'B93FFB'

UNION ALL

SELECT 
    '=== ダッシュボード表示値との比較 ===' as title,
    user_id,
    email,
    'Total Investment' as metric,
    (
        WITH RECURSIVE all_referrals AS (
            SELECT user_id, referrer_user_id, total_purchases
            FROM users
            WHERE referrer_user_id = 'B93FFB'
              AND has_approved_nft = true
            
            UNION ALL
            
            SELECT u.user_id, u.referrer_user_id, u.total_purchases
            FROM users u
            INNER JOIN all_referrals ar ON u.referrer_user_id = ar.user_id
            WHERE u.has_approved_nft = true
        )
        SELECT SUM(
            FLOOR(CAST(total_purchases AS DECIMAL) / 1100) * 1000
        )
        FROM all_referrals
    ) as value
FROM users 
WHERE user_id = 'B93FFB';

-- クリーンアップ
DROP TABLE IF EXISTS level_verification;