-- ========================================
-- 1月referral_amount最終修正
-- NFT購入なし: cum_usdt - withdrawn_referral_usdt
-- NFT購入あり: cum_usdt（NFT購入後はリセット）
-- HOLDフェーズ: さらに-$1,100
-- ========================================

-- 1. 修正前確認
SELECT '=== 1. 修正前（主要ユーザー） ===' as section;
SELECT
  mw.user_id,
  ac.phase,
  ac.auto_nft_count,
  ROUND(ac.cum_usdt::numeric, 2) as cum_usdt,
  ROUND(COALESCE(ac.withdrawn_referral_usdt, 0)::numeric, 2) as withdrawn,
  ROUND(mw.referral_amount::numeric, 2) as "現在referral"
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2026-01-01'
  AND mw.user_id IN ('7A9637', '177B83', '59C23C', '380CE2', '5FAE2C');

-- 2. 全ユーザー更新
UPDATE monthly_withdrawals mw
SET
  referral_amount = CASE
    -- NFT購入あり: cum_usdtをそのまま使用
    WHEN ac.auto_nft_count > 0 THEN
      CASE
        WHEN ac.phase = 'USDT' THEN ROUND(GREATEST(0, ac.cum_usdt)::numeric, 2)
        WHEN ac.phase = 'HOLD' THEN ROUND(GREATEST(0, ac.cum_usdt - 1100)::numeric, 2)
        ELSE 0
      END
    -- NFT購入なし: cum_usdt - withdrawn_referral_usdt
    ELSE
      CASE
        WHEN ac.phase = 'USDT' THEN ROUND(GREATEST(0, ac.cum_usdt - COALESCE(ac.withdrawn_referral_usdt, 0))::numeric, 2)
        WHEN ac.phase = 'HOLD' THEN ROUND(GREATEST(0, ac.cum_usdt - 1100 - COALESCE(ac.withdrawn_referral_usdt, 0))::numeric, 2)
        ELSE 0
      END
  END,
  total_amount = mw.personal_amount + CASE
    WHEN ac.auto_nft_count > 0 THEN
      CASE
        WHEN ac.phase = 'USDT' THEN ROUND(GREATEST(0, ac.cum_usdt)::numeric, 2)
        WHEN ac.phase = 'HOLD' THEN ROUND(GREATEST(0, ac.cum_usdt - 1100)::numeric, 2)
        ELSE 0
      END
    ELSE
      CASE
        WHEN ac.phase = 'USDT' THEN ROUND(GREATEST(0, ac.cum_usdt - COALESCE(ac.withdrawn_referral_usdt, 0))::numeric, 2)
        WHEN ac.phase = 'HOLD' THEN ROUND(GREATEST(0, ac.cum_usdt - 1100 - COALESCE(ac.withdrawn_referral_usdt, 0))::numeric, 2)
        ELSE 0
      END
  END
FROM affiliate_cycle ac
WHERE mw.user_id = ac.user_id
  AND mw.withdrawal_month = '2026-01-01'
  AND mw.status IN ('pending', 'on_hold');

-- 3. 修正後確認
SELECT '=== 3. 修正後（主要ユーザー） ===' as section;
SELECT
  mw.user_id,
  ac.phase,
  ac.auto_nft_count as "NFT購入",
  ROUND(ac.cum_usdt::numeric, 2) as cum_usdt,
  ROUND(COALESCE(ac.withdrawn_referral_usdt, 0)::numeric, 2) as withdrawn,
  ROUND(mw.personal_amount::numeric, 2) as "個人利益",
  ROUND(mw.referral_amount::numeric, 2) as "紹介報酬",
  ROUND(mw.total_amount::numeric, 2) as "出金合計"
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2026-01-01'
  AND mw.user_id IN ('7A9637', '177B83', '59C23C', '380CE2', '5FAE2C');

-- 4. 全体統計
SELECT '=== 4. 全体統計 ===' as section;
SELECT
  COUNT(*) as "総数",
  COUNT(*) FILTER (WHERE referral_amount > 0) as "referral>0",
  ROUND(SUM(referral_amount)::numeric, 2) as "紹介報酬合計",
  ROUND(SUM(total_amount)::numeric, 2) as "出金合計"
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-01-01'
  AND status IN ('pending', 'on_hold');
