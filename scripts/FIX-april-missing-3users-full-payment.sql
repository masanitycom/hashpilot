-- ========================================
-- 4月の月末出金リストから漏れた3名を満額支払いで追加
-- 2F6364, 59C23C, CA7902
-- ========================================
-- 方針:
--   過去の過払い債務（59C23Cの$1,090.84など）は会社負担とする
--   available_usdtを4月の新規収入額にリセット
--   monthly_withdrawals(2026-04-01)レコードを手動作成
-- ========================================

-- ========== STEP 1: 実行前の状態確認 ==========

-- 1-1. 修正前の状態
SELECT
  ac.user_id,
  u.email,
  ROUND(ac.available_usdt::numeric, 2) as available_usdt_before,
  ROUND(ac.cum_usdt::numeric, 2) as cum_usdt,
  ROUND(COALESCE(ac.withdrawn_referral_usdt, 0)::numeric, 2) as withdrawn_referral,
  ac.phase,
  ac.auto_nft_count,
  u.coinw_uid,
  u.nft_receive_address
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
WHERE ac.user_id IN ('2F6364', '59C23C', 'CA7902')
ORDER BY ac.user_id;

-- 1-2. 4月のmonthly_withdrawalsが本当に存在しないか確認
SELECT user_id, withdrawal_month, status, total_amount
FROM monthly_withdrawals
WHERE user_id IN ('2F6364', '59C23C', 'CA7902')
  AND withdrawal_month = '2026-04-01';
-- → 0件が想定

-- ========== STEP 2: バックアップ ==========

DROP TABLE IF EXISTS backup_april_missing_3users;
CREATE TABLE backup_april_missing_3users AS
SELECT * FROM affiliate_cycle
WHERE user_id IN ('2F6364', '59C23C', 'CA7902');

SELECT * FROM backup_april_missing_3users;

-- ========== STEP 3: available_usdtを4月の新規収入にリセット ==========
-- 過払い債務は会社負担とする（write-off）

UPDATE affiliate_cycle
SET available_usdt = 47.70,
    last_updated = NOW()
WHERE user_id = '2F6364';

UPDATE affiliate_cycle
SET available_usdt = 211.17,
    last_updated = NOW()
WHERE user_id = '59C23C';

UPDATE affiliate_cycle
SET available_usdt = 24.38,
    last_updated = NOW()
WHERE user_id = 'CA7902';

-- ========== STEP 4: 4月のmonthly_withdrawalsを手動作成 ==========

INSERT INTO monthly_withdrawals (
  user_id, withdrawal_month, status,
  personal_amount, referral_amount, total_amount,
  task_completed, withdrawal_method, withdrawal_address,
  notes, created_at, updated_at
)
SELECT
  data.user_id,
  '2026-04-01'::DATE,
  'on_hold',
  data.personal_amount,
  data.referral_amount,
  data.total_amount,
  false,
  CASE
    WHEN u.coinw_uid IS NOT NULL THEN 'coinw'
    WHEN u.nft_receive_address IS NOT NULL THEN 'bep20'
    ELSE NULL
  END,
  COALESCE(u.coinw_uid, u.nft_receive_address),
  '過去の過払い債務をwrite-offし、4月新規収入で補填'::TEXT,
  NOW(),
  NOW()
FROM (VALUES
  ('2F6364', 42.40, 5.30, 47.70),
  ('59C23C', 27.24, 183.93, 211.17),
  ('CA7902', 10.60, 13.78, 24.38)
) AS data(user_id, personal_amount, referral_amount, total_amount)
JOIN users u ON data.user_id = u.user_id;

-- ========== STEP 5: 結果検証 ==========

-- 5-1. 修正後のaffiliate_cycle
SELECT
  ac.user_id,
  u.email,
  ROUND(ac.available_usdt::numeric, 2) as available_usdt_after,
  ROUND(ac.cum_usdt::numeric, 2) as cum_usdt,
  ac.phase
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
WHERE ac.user_id IN ('2F6364', '59C23C', 'CA7902')
ORDER BY ac.user_id;

-- 5-2. 作成された4月レコード
SELECT
  user_id,
  withdrawal_month,
  status,
  ROUND(personal_amount::numeric, 2) as personal,
  ROUND(referral_amount::numeric, 2) as referral,
  ROUND(total_amount::numeric, 2) as total,
  withdrawal_method,
  withdrawal_address,
  notes
FROM monthly_withdrawals
WHERE user_id IN ('2F6364', '59C23C', 'CA7902')
  AND withdrawal_month = '2026-04-01'
ORDER BY user_id;

-- 5-3. 整合性チェック
SELECT * FROM check_monthly_integrity(2026, 4);

-- ========== STEP 6: 完了 ==========
SELECT '✅ 3名の4月分を追加しました（合計 $283.25）' as status;

-- ========================================
-- ロールバック手順（異常時）
-- ========================================
-- DELETE FROM monthly_withdrawals
-- WHERE user_id IN ('2F6364', '59C23C', 'CA7902')
--   AND withdrawal_month = '2026-04-01';
--
-- UPDATE affiliate_cycle ac
-- SET available_usdt = b.available_usdt,
--     last_updated = b.last_updated
-- FROM backup_april_missing_3users b
-- WHERE ac.user_id = b.user_id;
-- ========================================
