-- ========================================
-- monthly_withdrawalsにphaseカラムを追加
-- 出金作成時のフェーズを保存
-- 実行日: 2026-01-13
-- ========================================

-- ========================================
-- STEP 1: phaseカラム追加
-- ========================================
ALTER TABLE monthly_withdrawals
ADD COLUMN IF NOT EXISTS phase VARCHAR(10);

COMMENT ON COLUMN monthly_withdrawals.phase IS '出金作成時のフェーズ（USDT/HOLD）';

-- ========================================
-- STEP 2: 既存データのphaseを推定して設定
-- total_amount = personal_amount → HOLD（紹介報酬なし）
-- total_amount > personal_amount → USDT（紹介報酬あり）
-- ========================================
UPDATE monthly_withdrawals
SET phase = CASE
  WHEN ABS(total_amount - personal_amount) < 0.01 THEN 'HOLD'
  WHEN total_amount > personal_amount + 0.01 THEN 'USDT'
  ELSE 'USDT'
END
WHERE phase IS NULL;

-- ========================================
-- STEP 3: 確認
-- ========================================
SELECT
  user_id,
  TO_CHAR(withdrawal_month, 'YYYY-MM') as month,
  phase as withdrawal_phase,
  personal_amount,
  referral_amount,
  total_amount,
  CASE
    WHEN phase = 'HOLD' AND referral_amount > 0.01 THEN 'CHECK'
    ELSE 'OK'
  END as status
FROM monthly_withdrawals
WHERE user_id IN ('59C23C', '177B83')
ORDER BY user_id, withdrawal_month DESC;
