-- ========================================
-- 実際の出金対象ユーザー数を確認
-- ========================================

-- 1. available_usdt >= 10 のユーザー数（ペガサス制限なし）
SELECT '=== 1. 出金対象ユーザー（available_usdt >= 10、ペガサス制限なし） ===' as section;

SELECT
    COUNT(*) as eligible_count,
    SUM(ac.available_usdt) as total_amount,
    MIN(ac.available_usdt) as min_amount,
    MAX(ac.available_usdt) as max_amount,
    AVG(ac.available_usdt) as avg_amount
FROM users u
INNER JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE ac.available_usdt >= 10
  AND NOT (
      COALESCE(u.is_pegasus_exchange, FALSE) = TRUE
      AND (
          u.pegasus_withdrawal_unlock_date IS NULL
          OR CURRENT_DATE < u.pegasus_withdrawal_unlock_date
      )
  );

-- 2. 金額帯別の分布
SELECT '=== 2. 金額帯別の分布 ===' as section;

SELECT
    CASE
        WHEN ac.available_usdt >= 200 THEN '$200以上'
        WHEN ac.available_usdt >= 100 THEN '$100～$199'
        WHEN ac.available_usdt >= 50 THEN '$50～$99'
        WHEN ac.available_usdt >= 20 THEN '$20～$49'
        ELSE '$10～$19'
    END as amount_range,
    COUNT(*) as user_count,
    SUM(ac.available_usdt) as total_amount
FROM users u
INNER JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE ac.available_usdt >= 10
  AND NOT (
      COALESCE(u.is_pegasus_exchange, FALSE) = TRUE
      AND (
          u.pegasus_withdrawal_unlock_date IS NULL
          OR CURRENT_DATE < u.pegasus_withdrawal_unlock_date
      )
  )
GROUP BY
    CASE
        WHEN ac.available_usdt >= 200 THEN '$200以上'
        WHEN ac.available_usdt >= 100 THEN '$100～$199'
        WHEN ac.available_usdt >= 50 THEN '$50～$99'
        WHEN ac.available_usdt >= 20 THEN '$20～$49'
        ELSE '$10～$19'
    END
ORDER BY MIN(ac.available_usdt) DESC;

-- 3. 送金先設定状況
SELECT '=== 3. 送金先設定状況 ===' as section;

SELECT
    CASE
        WHEN u.coinw_uid IS NOT NULL AND u.coinw_uid != '' THEN 'CoinW設定済み'
        WHEN u.nft_receive_address IS NOT NULL AND u.nft_receive_address != '' THEN 'BEP20設定済み'
        ELSE '送金先未設定'
    END as withdrawal_method_status,
    COUNT(*) as user_count,
    SUM(ac.available_usdt) as total_amount
FROM users u
INNER JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE ac.available_usdt >= 10
  AND NOT (
      COALESCE(u.is_pegasus_exchange, FALSE) = TRUE
      AND (
          u.pegasus_withdrawal_unlock_date IS NULL
          OR CURRENT_DATE < u.pegasus_withdrawal_unlock_date
      )
  )
GROUP BY
    CASE
        WHEN u.coinw_uid IS NOT NULL AND u.coinw_uid != '' THEN 'CoinW設定済み'
        WHEN u.nft_receive_address IS NOT NULL AND u.nft_receive_address != '' THEN 'BEP20設定済み'
        ELSE '送金先未設定'
    END
ORDER BY user_count DESC;

-- 4. ペガサス制限ユーザー（除外される）
SELECT '=== 4. ペガサス制限ユーザー（除外） ===' as section;

SELECT
    COUNT(*) as pegasus_restricted_count,
    SUM(ac.available_usdt) as total_amount
FROM users u
INNER JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE ac.available_usdt >= 10
  AND u.is_pegasus_exchange = true
  AND (
      u.pegasus_withdrawal_unlock_date IS NULL
      OR CURRENT_DATE < u.pegasus_withdrawal_unlock_date
  );

-- 5. 全ユーザーの available_usdt 分布（参考）
SELECT '=== 5. 全ユーザーの available_usdt 分布 ===' as section;

SELECT
    CASE
        WHEN ac.available_usdt >= 200 THEN '$200以上'
        WHEN ac.available_usdt >= 100 THEN '$100～$199'
        WHEN ac.available_usdt >= 50 THEN '$50～$99'
        WHEN ac.available_usdt >= 20 THEN '$20～$49'
        WHEN ac.available_usdt >= 10 THEN '$10～$19'
        WHEN ac.available_usdt >= 1 THEN '$1～$9'
        ELSE '$0～$0.99'
    END as amount_range,
    COUNT(*) as user_count,
    SUM(ac.available_usdt) as total_amount
FROM affiliate_cycle ac
GROUP BY
    CASE
        WHEN ac.available_usdt >= 200 THEN '$200以上'
        WHEN ac.available_usdt >= 100 THEN '$100～$199'
        WHEN ac.available_usdt >= 50 THEN '$50～$99'
        WHEN ac.available_usdt >= 20 THEN '$20～$49'
        WHEN ac.available_usdt >= 10 THEN '$10～$19'
        WHEN ac.available_usdt >= 1 THEN '$1～$9'
        ELSE '$0～$0.99'
    END
ORDER BY MIN(ac.available_usdt) DESC;

-- 6. 運用中のNFT保有者数（参考）
SELECT '=== 6. NFT保有状況（参考） ===' as section;

SELECT
    COUNT(DISTINCT u.user_id) as total_users,
    COUNT(DISTINCT CASE WHEN u.has_approved_nft = true THEN u.user_id END) as has_nft_users,
    COUNT(DISTINCT CASE WHEN ac.available_usdt >= 10 THEN u.user_id END) as over_10_users,
    COUNT(DISTINCT CASE WHEN ac.available_usdt >= 10 AND u.has_approved_nft = true THEN u.user_id END) as eligible_and_has_nft
FROM users u
INNER JOIN affiliate_cycle ac ON u.user_id = ac.user_id;

-- 7. 11/30の日利が設定されているか確認
SELECT '=== 7. 11/30の日利設定確認 ===' as section;

SELECT
    COUNT(DISTINCT user_id) as users_with_1130_profit,
    SUM(profit_amount) as total_profit_1130
FROM user_daily_profit
WHERE date = '2025-11-30';
