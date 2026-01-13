-- ========================================
-- phaseカラムの修正（正しいロジック）
-- 実行日: 2026-01-13
-- ========================================
--
-- 正しいロジック:
-- 1. referral_amount > 0 かつ total に含まれている → USDT（紹介報酬出金済み）
-- 2. referral_amount > 0 かつ total に含まれていない → HOLD（紹介報酬ロック）
-- 3. referral_amount = 0 → 現在のフェーズを使用
--
-- 間違っていたロジック:
-- total = personal → HOLD（これだと紹介報酬0の人もHOLDになってしまう）
-- ========================================

-- STEP 1: 全てリセット
UPDATE monthly_withdrawals SET phase = NULL;

-- STEP 2: 正しいロジックで設定
-- referral_amount > 0 の場合のみ判定
-- それ以外は現在のフェーズを使う
UPDATE monthly_withdrawals mw
SET phase = CASE
  -- 紹介報酬があり、total に含まれている → 出金時USDT
  WHEN mw.referral_amount > 0.01 AND mw.total_amount > mw.personal_amount + 0.01 THEN 'USDT'
  -- 紹介報酬があるが、total に含まれていない → 出金時HOLD
  WHEN mw.referral_amount > 0.01 AND ABS(mw.total_amount - mw.personal_amount) < 0.01 THEN 'HOLD'
  -- 紹介報酬がない → 現在のフェーズを使用
  ELSE ac.phase
END
FROM affiliate_cycle ac
WHERE mw.user_id = ac.user_id;

-- STEP 3: affiliate_cycleがないユーザー（あれば）はUSDTをデフォルト
UPDATE monthly_withdrawals
SET phase = 'USDT'
WHERE phase IS NULL;

-- STEP 4: 確認
SELECT
  mw.user_id,
  TO_CHAR(mw.withdrawal_month, 'YYYY-MM') as month,
  mw.phase as withdrawal_phase,
  ac.phase as current_phase,
  mw.personal_amount,
  mw.referral_amount,
  mw.total_amount
FROM monthly_withdrawals mw
LEFT JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.user_id IN ('9A3A16', 'A4C3C8', '59C23C', '177B83', '4E9884')
ORDER BY mw.total_amount DESC;

-- 統計
SELECT
  phase,
  COUNT(*) as count,
  SUM(total_amount) as total
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-12-01'
GROUP BY phase
ORDER BY count DESC;
