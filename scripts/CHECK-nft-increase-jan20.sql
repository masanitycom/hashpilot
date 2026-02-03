-- ========================================
-- 1/20にNFT数が増えた原因調査
-- ========================================
-- 運用開始日は1日か15日のみのはず
-- 1/20に増えるのはおかしい

-- 0. 1/20に運用開始日が設定されているユーザー（異常データの可能性）
SELECT '=== 0. users.operation_start_date = 2026-01-20 のユーザー（異常データ） ===' as section;
SELECT
  user_id,
  email,
  operation_start_date,
  has_approved_nft,
  is_pegasus_exchange,
  (SELECT COUNT(*) FROM nft_master nm WHERE nm.user_id = u.user_id AND nm.buyback_date IS NULL) as nft_count
FROM users u
WHERE operation_start_date = '2026-01-20';

-- 0-2. 1日と15日以外のoperation_start_dateを持つユーザー（全ての異常データ）
SELECT '=== 0-2. 1日/15日以外のoperation_start_dateを持つユーザー（異常） ===' as section;
SELECT
  user_id,
  email,
  operation_start_date,
  EXTRACT(DAY FROM operation_start_date) as day_of_month,
  has_approved_nft,
  (SELECT COUNT(*) FROM nft_master nm WHERE nm.user_id = u.user_id AND nm.buyback_date IS NULL) as nft_count
FROM users u
WHERE operation_start_date IS NOT NULL
  AND EXTRACT(DAY FROM operation_start_date) NOT IN (1, 15)
ORDER BY operation_start_date;

-- 1. 1/20にoperation_start_dateが来るユーザー（ユーザー単位）
SELECT '=== 1. users.operation_start_date = 2026-01-20 のユーザー ===' as section;
SELECT
  user_id,
  email,
  operation_start_date,
  has_approved_nft,
  (SELECT COUNT(*) FROM nft_master nm WHERE nm.user_id = u.user_id AND nm.buyback_date IS NULL) as nft_count
FROM users u
WHERE operation_start_date = '2026-01-20'
  AND (is_pegasus_exchange = FALSE OR is_pegasus_exchange IS NULL);

-- 2. 1/20にoperation_start_dateが来るNFT（NFT単位）
SELECT '=== 2. nft_master.operation_start_date = 2026-01-20 のNFT ===' as section;
SELECT
  nm.user_id,
  u.email,
  nm.acquired_date,
  nm.operation_start_date,
  nm.nft_type
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.operation_start_date = '2026-01-20'
  AND nm.buyback_date IS NULL
  AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL);

-- 3. 1/19と1/20のNFT数比較（ユーザーのoperation_start_dateベース）
SELECT '=== 3. users.operation_start_dateベースのNFT数 ===' as section;
SELECT
  '2026-01-19' as 日付,
  COUNT(*) as NFT数
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2026-01-19'
  AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)
UNION ALL
SELECT
  '2026-01-20' as 日付,
  COUNT(*) as NFT数
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2026-01-20'
  AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL);

-- 4. 1/19と1/20のNFT数比較（NFTのoperation_start_dateベース）
SELECT '=== 4. nft_master.operation_start_dateベースのNFT数 ===' as section;
SELECT
  '2026-01-19' as 日付,
  COUNT(*) as NFT数
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND nm.operation_start_date IS NOT NULL
  AND nm.operation_start_date <= '2026-01-19'
  AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)
UNION ALL
SELECT
  '2026-01-20' as 日付,
  COUNT(*) as NFT数
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND nm.operation_start_date IS NOT NULL
  AND nm.operation_start_date <= '2026-01-20'
  AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL);

-- 5. 本番環境のprocess_daily_yield_v2関数の定義を確認
SELECT '=== 5. 本番環境の関数定義確認 ===' as section;
SELECT
  routine_name,
  routine_definition
FROM information_schema.routines
WHERE routine_name = 'process_daily_yield_v2'
  AND routine_schema = 'public';

-- 6. operation_start_dateが設定されていないNFT
SELECT '=== 6. operation_start_date未設定のNFT ===' as section;
SELECT
  nm.user_id,
  nm.acquired_date,
  nm.nft_type,
  u.operation_start_date as user_operation_start_date
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND nm.operation_start_date IS NULL
  AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL);

-- 7. daily_yield_log_v2の作成日時を確認（後日修正された可能性）
SELECT '=== 7. daily_yield_log_v2の作成日時（後日修正の確認） ===' as section;
SELECT
  date,
  total_nft_count,
  total_profit_amount,
  created_at,
  created_at::date as 設定日,
  CASE WHEN created_at::date > date THEN '★後日修正' ELSE '' END as 備考
FROM daily_yield_log_v2
WHERE date >= '2026-01-15'
ORDER BY date;

-- 8. 本番環境のprocess_daily_yield_v2関数定義（operation_start_dateの使い方を確認）
SELECT '=== 8. process_daily_yield_v2関数のoperation_start_date使用箇所 ===' as section;
SELECT
  pg_get_functiondef(oid) as 関数定義
FROM pg_proc
WHERE proname = 'process_daily_yield_v2';
