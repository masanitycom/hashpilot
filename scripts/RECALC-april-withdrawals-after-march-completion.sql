-- ========================================
-- 4月分の月末出金レコードを再計算
-- ========================================
-- 背景:
--   3月分の送金は4月頭に実施済みだが、担当者が「送金済みにする」処理を
--   忘れていたため、4月末の月末処理時点で available_usdt に3月残高が
--   残ったまま4月のレコードが作成された。
--   結果、4月の total_amount が「3月残高 + 4月利益」の合計値で
--   膨らんでしまっている。
--
-- 前提条件（実行前に必ず確認）:
--   ✅ 3月分の monthly_withdrawals が全て completed になっていること
--   ✅ 5月分の日利処理がまだ実行されていないこと
--   ✅ available_usdt が3月送金分を差し引いた正しい値になっていること
-- ========================================

-- ========== STEP 1: 実行前の状態確認 ==========

-- 1-1. 3月分が全て completed になっているか確認
SELECT
  status,
  COUNT(*) as count,
  SUM(total_amount) as total_sum
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-03-01'
GROUP BY status
ORDER BY status;
-- → status = 'pending' が 0 件であることを確認
-- → 'on_hold'（CoinW繰越）は残っていてもOK

-- 1-2. 4月分の現状確認（再計算前）
SELECT
  status,
  COUNT(*) as count,
  SUM(personal_amount) as personal_sum,
  SUM(referral_amount) as referral_sum,
  SUM(total_amount) as total_sum
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-04-01'
GROUP BY status
ORDER BY status;

-- 1-3. 5月分の日利が入っていないか確認（重要）
SELECT
  date,
  COUNT(*) as user_count,
  SUM(daily_profit) as total_profit
FROM nft_daily_profit
WHERE date >= '2026-05-01'
GROUP BY date
ORDER BY date;
-- → 結果が0件であることを確認！
-- → もし結果があれば中止して相談すること

-- ========== STEP 2: バックアップ取得 ==========

-- 念のため4月分のpending/on_holdをバックアップ
CREATE TABLE IF NOT EXISTS backup_monthly_withdrawals_april_2026 AS
SELECT * FROM monthly_withdrawals
WHERE withdrawal_month = '2026-04-01'
  AND status IN ('pending', 'on_hold');

SELECT
  'backup_monthly_withdrawals_april_2026' as table_name,
  COUNT(*) as backup_rows
FROM backup_monthly_withdrawals_april_2026;

-- ========== STEP 3: 4月分のpendingレコードを削除 ==========
-- 注意: completedとon_holdは触らない

DELETE FROM monthly_withdrawals
WHERE withdrawal_month = '2026-04-01'
  AND status = 'pending';

-- 削除件数を確認
SELECT COUNT(*) as remaining_april_records
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-04-01';
-- → on_hold分だけが残るはず

-- ========== STEP 4: 4月分を再生成 ==========

SELECT * FROM process_monthly_withdrawals('2026-04-30');

-- ========== STEP 5: 結果検証 ==========

-- 5-1. 再生成後の4月分
SELECT
  status,
  COUNT(*) as count,
  SUM(personal_amount) as personal_sum,
  SUM(referral_amount) as referral_sum,
  SUM(total_amount) as total_sum
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-04-01'
GROUP BY status
ORDER BY status;

-- 5-2. 整合性チェック
SELECT * FROM check_monthly_integrity(2026, 4);

-- 5-3. 個別ユーザーの金額確認（上位20件）
SELECT
  mw.user_id,
  u.email,
  ac.phase,
  mw.personal_amount,
  mw.referral_amount,
  mw.total_amount,
  ac.available_usdt,
  ac.cum_usdt,
  ac.withdrawn_referral_usdt
FROM monthly_withdrawals mw
LEFT JOIN users u ON mw.user_id = u.user_id
LEFT JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2026-04-01'
  AND mw.status = 'pending'
ORDER BY mw.total_amount DESC
LIMIT 20;

-- ========== STEP 6: 問題なければ完了 ==========
SELECT '✅ 4月分の再計算が完了しました。check_monthly_integrityでNGがないことを確認してください。' as status;

-- ========================================
-- 異常時のロールバック手順
-- ========================================
-- もし結果が想定と異なる場合は以下で復元可能:
--
-- DELETE FROM monthly_withdrawals
-- WHERE withdrawal_month = '2026-04-01'
--   AND status = 'pending';
--
-- INSERT INTO monthly_withdrawals
-- SELECT * FROM backup_monthly_withdrawals_april_2026
-- WHERE status = 'pending';
-- ========================================
