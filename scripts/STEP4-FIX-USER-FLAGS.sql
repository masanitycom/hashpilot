-- ========================================
-- STEP 4: ユーザーフラグの一括修正
-- ========================================
-- 91ユーザーの has_approved_nft と operation_start_date を修正
-- 実行前にSTEP1でバックアップを作成してください
-- ========================================

-- ========================================
-- STEP 4-1: 修正前の確認
-- ========================================

-- has_approved_nft = false だが、NFTとpurchasesが存在するユーザー
SELECT
    '🚨 has_approved_nft修正対象' as label,
    COUNT(DISTINCT u.user_id) as user_count,
    SUM(p.amount_usd * (1000.0 / 1100.0)) as total_investment,
    SUM(FLOOR(p.amount_usd / 1100.0)) as total_nft
FROM users u
INNER JOIN nft_master nm ON u.user_id = nm.user_id
INNER JOIN purchases p ON u.user_id = p.user_id
WHERE u.has_approved_nft = false
    AND p.admin_approved = true
    AND nm.buyback_date IS NULL;

-- operation_start_date = NULL だが、NFTとpurchasesが存在するユーザー
SELECT
    '🚨 operation_start_date修正対象' as label,
    COUNT(DISTINCT u.user_id) as user_count,
    SUM(p.amount_usd * (1000.0 / 1100.0)) as total_investment,
    SUM(FLOOR(p.amount_usd / 1100.0)) as total_nft
FROM users u
INNER JOIN nft_master nm ON u.user_id = nm.user_id
INNER JOIN purchases p ON u.user_id = p.user_id
WHERE u.operation_start_date IS NULL
    AND p.admin_approved = true
    AND nm.buyback_date IS NULL;

-- 詳細リスト（上位20件）
SELECT
    '👤 修正対象ユーザー詳細（上位20件）' as label,
    u.user_id,
    u.full_name,
    u.has_approved_nft,
    u.operation_start_date,
    COUNT(DISTINCT nm.id) as nft_count,
    COUNT(DISTINCT p.id) as purchase_count,
    SUM(p.amount_usd * (1000.0 / 1100.0)) as investment_value,
    MIN(nm.acquired_date) as first_nft_acquired,
    calculate_operation_start_date(MIN(nm.acquired_date)) as calculated_operation_start
FROM users u
INNER JOIN nft_master nm ON u.user_id = nm.user_id
INNER JOIN purchases p ON u.user_id = p.user_id
WHERE (u.has_approved_nft = false OR u.operation_start_date IS NULL)
    AND p.admin_approved = true
    AND nm.buyback_date IS NULL
GROUP BY u.user_id, u.full_name, u.has_approved_nft, u.operation_start_date
ORDER BY investment_value DESC
LIMIT 20;

-- ========================================
-- STEP 4-2: has_approved_nft の一括更新
-- ========================================
-- ⚠️ この下のコメントを外して実行してください
-- ⚠️ 実行前に上記の確認結果を確認してください
-- ========================================

/*
BEGIN;

-- has_approved_nft を true に更新
UPDATE users
SET
    has_approved_nft = true,
    updated_at = NOW()
WHERE user_id IN (
    SELECT DISTINCT u.user_id
    FROM users u
    INNER JOIN nft_master nm ON u.user_id = nm.user_id
    INNER JOIN purchases p ON u.user_id = p.user_id
    WHERE u.has_approved_nft = false
        AND p.admin_approved = true
        AND nm.buyback_date IS NULL
);

-- 更新件数を確認
SELECT
    '✅ has_approved_nft更新完了' as status,
    (SELECT COUNT(*) FROM users WHERE has_approved_nft = true) as total_approved_users,
    (SELECT COUNT(DISTINCT u.user_id)
     FROM users u
     INNER JOIN nft_master nm ON u.user_id = nm.user_id
     INNER JOIN purchases p ON u.user_id = p.user_id
     WHERE u.has_approved_nft = false
        AND p.admin_approved = true
        AND nm.buyback_date IS NULL
    ) as remaining_issues;

-- 問題がなければコミット
COMMIT;
-- ROLLBACK; -- 問題があればこちらを実行
*/

-- ========================================
-- STEP 4-3: operation_start_date の一括更新
-- ========================================
-- ⚠️ この下のコメントを外して実行してください
-- ⚠️ STEP 4-2が完了してから実行してください
-- ========================================

/*
BEGIN;

-- operation_start_date を設定（各ユーザーの最初のNFT取得日から計算）
UPDATE users u
SET
    operation_start_date = calculate_operation_start_date(nm.acquired_date),
    updated_at = NOW()
FROM (
    SELECT DISTINCT ON (user_id)
        user_id,
        acquired_date
    FROM nft_master
    WHERE buyback_date IS NULL
    ORDER BY user_id, acquired_date ASC
) nm
WHERE u.user_id = nm.user_id
    AND u.operation_start_date IS NULL
    AND u.has_approved_nft = true;

-- 更新件数を確認
SELECT
    '✅ operation_start_date更新完了' as status,
    (SELECT COUNT(*) FROM users WHERE operation_start_date IS NOT NULL AND has_approved_nft = true) as total_users_with_start_date,
    (SELECT COUNT(DISTINCT u.user_id)
     FROM users u
     INNER JOIN nft_master nm ON u.user_id = nm.user_id
     INNER JOIN purchases p ON u.user_id = p.user_id
     WHERE u.operation_start_date IS NULL
        AND p.admin_approved = true
        AND nm.buyback_date IS NULL
    ) as remaining_issues;

-- 問題がなければコミット
COMMIT;
-- ROLLBACK; -- 問題があればこちらを実行
*/

-- ========================================
-- STEP 4-4: 更新後の確認
-- ========================================

-- has_approved_nft = false だが、NFTが存在するユーザー（0件であるべき）
SELECT
    '✅ 修正後の確認: has_approved_nft' as label,
    COUNT(DISTINCT u.user_id) as remaining_users,
    CASE
        WHEN COUNT(DISTINCT u.user_id) = 0 THEN '✅ 問題なし'
        ELSE '❌ まだ問題が残っています'
    END as status
FROM users u
INNER JOIN nft_master nm ON u.user_id = nm.user_id
INNER JOIN purchases p ON u.user_id = p.user_id
WHERE u.has_approved_nft = false
    AND p.admin_approved = true
    AND nm.buyback_date IS NULL;

-- operation_start_date = NULL だが、NFTが存在するユーザー（0件であるべき）
SELECT
    '✅ 修正後の確認: operation_start_date' as label,
    COUNT(DISTINCT u.user_id) as remaining_users,
    CASE
        WHEN COUNT(DISTINCT u.user_id) = 0 THEN '✅ 問題なし'
        ELSE '❌ まだ問題が残っています'
    END as status
FROM users u
INNER JOIN nft_master nm ON u.user_id = nm.user_id
INNER JOIN purchases p ON u.user_id = p.user_id
WHERE u.operation_start_date IS NULL
    AND p.admin_approved = true
    AND nm.buyback_date IS NULL;

-- 運用中のユーザー数と投資額を確認
SELECT
    '📊 運用中のユーザー（ペガサス除く）' as label,
    COUNT(DISTINCT u.user_id) as user_count,
    SUM(p.amount_usd * (1000.0 / 1100.0)) as total_investment,
    SUM(FLOOR(p.amount_usd / 1100.0)) as total_nft
FROM users u
INNER JOIN purchases p ON u.user_id = p.user_id
WHERE p.admin_approved = true
    AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)
    AND u.operation_start_date IS NOT NULL
    AND u.operation_start_date <= CURRENT_DATE;

-- ========================================
-- 完了メッセージ
-- ========================================
SELECT
    '✅ ユーザーフラグの修正完了' as status,
    '次のステップ: STEP5-DELETE-INCORRECT-DATA.sql を実行してください' as next_step;

-- ========================================
-- 重要: すべてのステータスが「✅ 問題なし」であることを確認してください
-- ========================================
