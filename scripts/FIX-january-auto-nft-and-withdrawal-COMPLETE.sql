-- ========================================
-- 1月NFT自動付与 + 出金データ修正（完全版）
-- ========================================

-- ========================================
-- PART 1: 177B83にNFT自動付与
-- ========================================
SELECT '=== PART 1: 177B83 NFT自動付与 ===' as section;

-- 1a. nft_masterにNFT追加
INSERT INTO nft_master (
  user_id,
  nft_sequence,
  nft_type,
  nft_value,
  acquired_date,
  operation_start_date,
  buyback_date
)
SELECT 
  '177B83',
  COALESCE(MAX(nft_sequence), 0) + 1,
  'auto',
  1000,
  '2026-01-31',
  '2026-02-15',  -- 1/31購入 → 翌月15日運用開始
  NULL
FROM nft_master
WHERE user_id = '177B83';

-- 1b. purchasesに記録
INSERT INTO purchases (
  user_id,
  nft_quantity,
  amount_usd,
  payment_status,
  admin_approved,
  admin_approved_at,
  cycle_number_at_purchase,
  is_auto_purchase
) VALUES (
  '177B83',
  1,
  1100,
  'completed',
  true,
  NOW(),
  1,
  true
);

-- 1c. affiliate_cycleを更新
UPDATE affiliate_cycle
SET 
  cum_usdt = cum_usdt - 1100,
  available_usdt = available_usdt + 1100,
  auto_nft_count = auto_nft_count + 1,
  total_nft_count = total_nft_count + 1,
  phase = 'HOLD',
  updated_at = NOW()
WHERE user_id = '177B83';

-- ========================================
-- PART 2: HOLDフェーズユーザーの出金データ修正
-- ========================================
SELECT '=== PART 2: HOLD出金データ修正 ===' as section;

UPDATE monthly_withdrawals
SET 
  referral_amount = 0,
  total_amount = personal_amount,
  updated_at = NOW()
WHERE user_id IN ('59C23C', '177B83')
  AND withdrawal_month = '2026-01-01';

-- ========================================
-- PART 3: 結果確認
-- ========================================
SELECT '=== 結果: affiliate_cycle ===' as section;
SELECT 
  user_id, cum_usdt, available_usdt, phase, auto_nft_count, total_nft_count
FROM affiliate_cycle 
WHERE user_id IN ('59C23C', '177B83');

SELECT '=== 結果: 1月出金データ ===' as section;
SELECT 
  user_id, total_amount, personal_amount, referral_amount,
  CASE WHEN total_amount < 10 THEN '⚠️ $10未満' ELSE '✓ OK' END as check
FROM monthly_withdrawals
WHERE user_id IN ('59C23C', '177B83')
  AND withdrawal_month = '2026-01-01';

SELECT '=== 結果: 177B83 NFT一覧 ===' as section;
SELECT nft_sequence, nft_type, acquired_date, operation_start_date
FROM nft_master WHERE user_id = '177B83' ORDER BY nft_sequence;
