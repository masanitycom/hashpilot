-- ========================================
-- 177B83 フェーズ計算の詳細確認
-- ========================================

-- フェーズ計算ロジック:
-- cum_usdt < 1100 → USDT（払い出し可能）
-- 1100 <= cum_usdt < 2200 → HOLD（次のNFT待ち）
-- cum_usdt >= 2200 → NFT付与後、cum_usdt -= 1100、USDT に戻る

-- 1. 177B83の現在のaffiliate_cycle状態
SELECT '=== 1. 177B83 affiliate_cycle ===' as section;
SELECT
  user_id,
  cum_usdt,
  available_usdt,
  phase,
  withdrawn_referral_usdt,
  auto_nft_count,
  manual_nft_count,
  total_nft_count
FROM affiliate_cycle
WHERE user_id = '177B83';

-- 2. フェーズ計算の確認
SELECT '=== 2. フェーズ計算 ===' as section;
SELECT
  user_id,
  cum_usdt,
  FLOOR(cum_usdt / 1100)::int as cycles_completed,
  (FLOOR(cum_usdt / 1100)::int % 2) as cycle_position,
  CASE
    WHEN (FLOOR(cum_usdt / 1100)::int % 2) = 0 THEN 'USDT'
    ELSE 'HOLD'
  END as calculated_phase,
  phase as current_phase
FROM affiliate_cycle
WHERE user_id = '177B83';

-- 3. 177B83の月次紹介報酬履歴
SELECT '=== 3. 月次紹介報酬履歴 ===' as section;
SELECT
  withdrawal_month,
  total_amount,
  personal_amount,
  referral_amount,
  status,
  created_at
FROM monthly_withdrawals
WHERE user_id = '177B83'
ORDER BY withdrawal_month;

-- 4. 全HOLDユーザーとフェーズ計算
SELECT '=== 4. 全ユーザーのフェーズ計算確認 ===' as section;
SELECT
  user_id,
  cum_usdt,
  phase as current_phase,
  FLOOR(cum_usdt / 1100)::int as cycles,
  (FLOOR(cum_usdt / 1100)::int % 2) as position,
  CASE
    WHEN (FLOOR(cum_usdt / 1100)::int % 2) = 0 THEN 'USDT'
    ELSE 'HOLD'
  END as calculated_phase,
  CASE
    WHEN phase != CASE WHEN (FLOOR(cum_usdt / 1100)::int % 2) = 0 THEN 'USDT' ELSE 'HOLD' END
    THEN '❌ 不一致'
    ELSE '✓'
  END as match_status
FROM affiliate_cycle
WHERE cum_usdt >= 1100
ORDER BY cum_usdt DESC;

-- 5. 177B83のphaseがUSDTの理由
-- cum_usdt = 1879.69
-- FLOOR(1879.69 / 1100) = 1
-- 1 % 2 = 1 → HOLD のはず
-- でも現在 USDT → 何かがおかしい？
SELECT '=== 5. 177B83 フェーズが USDT の理由 ===' as section;
SELECT
  '177B83のcum_usdt=' || cum_usdt ||
  ', FLOOR(cum_usdt/1100)=' || FLOOR(cum_usdt / 1100)::int ||
  ', mod 2=' || (FLOOR(cum_usdt / 1100)::int % 2) ||
  ' → 計算上は' || CASE WHEN (FLOOR(cum_usdt / 1100)::int % 2) = 0 THEN 'USDT' ELSE 'HOLD' END ||
  ', 現在のphase=' || phase as analysis
FROM affiliate_cycle
WHERE user_id = '177B83';
