-- ========================================
-- 177B83にNFT自動付与を実行
-- ========================================

-- STEP 1: 修正前の状態
SELECT '=== STEP 1: 修正前 ===' as section;
SELECT user_id, cum_usdt, available_usdt, phase, auto_nft_count, total_nft_count
FROM affiliate_cycle WHERE user_id = '177B83';

-- STEP 2: NFT自動付与を実行
SELECT '=== STEP 2: NFT自動付与 ===' as section;

-- 2a. nft_masterにNFT追加
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
  '2026-01-31',  -- 1月末に付与
  '2026-02-15',  -- 1/31は21日以降なので翌月15日運用開始
  NULL
FROM nft_master
WHERE user_id = '177B83';

-- 2b. purchasesに記録
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

-- 2c. affiliate_cycleを更新
UPDATE affiliate_cycle
SET 
  cum_usdt = cum_usdt - 1100,
  available_usdt = available_usdt + 1100,
  auto_nft_count = auto_nft_count + 1,
  total_nft_count = total_nft_count + 1,
  phase = 'HOLD',  -- $1,190.52 >= $1,100 なのでHOLD
  updated_at = NOW()
WHERE user_id = '177B83';

-- STEP 3: 修正後の状態
SELECT '=== STEP 3: 修正後 ===' as section;
SELECT user_id, cum_usdt, available_usdt, phase, auto_nft_count, total_nft_count
FROM affiliate_cycle WHERE user_id = '177B83';

SELECT '=== NFT一覧 ===' as section;
SELECT nft_sequence, nft_type, acquired_date, operation_start_date
FROM nft_master WHERE user_id = '177B83' ORDER BY nft_sequence;
