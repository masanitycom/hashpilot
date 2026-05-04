-- ========================================
-- 4月の月末出金リストから漏れた3名を満額支払いで追加 (v2)
-- emailカラム追加
-- ========================================

-- ========== STEP 4 (再実行): 4月のmonthly_withdrawalsを手動作成 ==========
-- v1のINSERTをemail込みで修正

INSERT INTO monthly_withdrawals (
  user_id, email, withdrawal_month, status,
  personal_amount, referral_amount, total_amount,
  task_completed, withdrawal_method, withdrawal_address,
  notes, created_at, updated_at
)
SELECT
  data.user_id,
  u.email,
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

-- 結果検証
SELECT
  user_id,
  email,
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

-- 整合性チェック
SELECT * FROM check_monthly_integrity(2026, 4);
