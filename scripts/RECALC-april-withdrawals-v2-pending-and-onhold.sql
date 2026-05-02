-- ========================================
-- 4月分の月末出金レコードを再計算（修正版v2）
-- ========================================
-- 背景:
--   3月分の送金完了処理が遅れたため、4月のtotal_amountが膨らんでいる。
--   pendingだけでなくon_holdも膨らんでいるため両方を削除して再作成する。
--
-- 前提条件（実行前確認）:
--   ✅ 3月分のpendingが0件（全てcompletedまたはon_holdに変換済み）
--   ✅ 5月分の日利が未投入
-- ========================================

-- ========== STEP 1: 実行前の最終確認 ==========

-- 1-1. 3月分のpendingが0件か再確認
SELECT
  status,
  COUNT(*) as count,
  SUM(total_amount) as total_sum
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-03-01'
GROUP BY status
ORDER BY status;
-- → pending = 0 件 を確認！

-- 1-2. 5月日利が0件か再確認
SELECT COUNT(*) as may_profit_count
FROM nft_daily_profit
WHERE date >= '2026-05-01';
-- → 0 を確認！

-- 1-3. 4月分の現状（再計算前）
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

-- ========== STEP 2: バックアップ取得 ==========

-- 既存のバックアップテーブルがあれば削除
DROP TABLE IF EXISTS backup_monthly_withdrawals_april_2026;

-- 4月のpending+on_holdをバックアップ（completedは触らないので除外）
CREATE TABLE backup_monthly_withdrawals_april_2026 AS
SELECT * FROM monthly_withdrawals
WHERE withdrawal_month = '2026-04-01'
  AND status IN ('pending', 'on_hold');

SELECT
  COUNT(*) as backup_rows,
  SUM(total_amount) as backup_total
FROM backup_monthly_withdrawals_april_2026;
-- → 452 件 / $56,537 程度になるはず

-- ========== STEP 3: 4月分のpending+on_holdを削除 ==========
-- ⚠️ completedは触らない！

DELETE FROM monthly_withdrawals
WHERE withdrawal_month = '2026-04-01'
  AND status IN ('pending', 'on_hold');

-- 残った4月レコードを確認（completedのみ残るはず、なければ0件でもOK）
SELECT
  status,
  COUNT(*) as count
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-04-01'
GROUP BY status;

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

-- 5-3. 上位20件の金額を確認
SELECT
  mw.user_id,
  u.email,
  ac.phase,
  mw.status,
  mw.personal_amount,
  mw.referral_amount,
  mw.total_amount,
  ac.available_usdt,
  ROUND((mw.total_amount - ac.available_usdt)::numeric, 2) as diff
FROM monthly_withdrawals mw
LEFT JOIN users u ON mw.user_id = u.user_id
LEFT JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2026-04-01'
  AND mw.status IN ('pending', 'on_hold')
ORDER BY mw.total_amount DESC
LIMIT 20;
-- → diffが全て0またはほぼ0であることを確認（total_amount = available_usdt）

-- 5-4. バックアップとの差分（誰がどれだけ減ったか）
SELECT
  b.user_id,
  u.email,
  b.total_amount as before_total,
  COALESCE(n.total_amount, 0) as after_total,
  ROUND((b.total_amount - COALESCE(n.total_amount, 0))::numeric, 2) as decreased_by
FROM backup_monthly_withdrawals_april_2026 b
LEFT JOIN monthly_withdrawals n ON b.user_id = n.user_id
  AND n.withdrawal_month = '2026-04-01'
LEFT JOIN users u ON b.user_id = u.user_id
WHERE b.total_amount - COALESCE(n.total_amount, 0) > 0.01
ORDER BY decreased_by DESC
LIMIT 20;
-- → 一番減った人 = 一番3月分の送金額が大きかった人

-- ========== STEP 6: 完了 ==========
SELECT '✅ 4月分の再計算が完了しました。check_monthly_integrityでNGがないことを確認してください。' as status;

-- ========================================
-- 異常時のロールバック手順
-- ========================================
-- 結果が異常な場合は以下で復元:
--
-- DELETE FROM monthly_withdrawals
-- WHERE withdrawal_month = '2026-04-01'
--   AND status IN ('pending', 'on_hold');
--
-- INSERT INTO monthly_withdrawals
-- SELECT * FROM backup_monthly_withdrawals_april_2026;
-- ========================================
