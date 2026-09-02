-- ============================================================
-- 7月分 完了処理の直後検証
-- 実行日: 2026-09-02
--
-- 照合すべき実送金額:
--   本体(HASHPILOT)     : $14,786.89
--   サブ(HASHPILOT_COPY): $172.75
--
-- ★ここで金額が合わなければ 8月分の修正に進んではいけない★
-- ============================================================

-- ------------------------------------------------------------
-- 【1】★最重要★ 完了した金額が実送金額と一致するか
-- ------------------------------------------------------------
SELECT
  status,
  COUNT(*)                              AS 件数,
  ROUND(SUM(total_amount)::numeric, 2)  AS 合計額
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-07-01'
GROUP BY status
ORDER BY status;

-- completed だけの合計（本体ならここが $14,786.89 になるはず）
SELECT
  COUNT(*)                              AS 完了件数,
  ROUND(SUM(total_amount)::numeric, 2)  AS 完了合計,
  ROUND(SUM(referral_amount)::numeric, 2) AS うち紹介報酬
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-07-01'
  AND status = 'completed';


-- ------------------------------------------------------------
-- 【2】完了処理で available_usdt がマイナスになった人
--   減算方式なので、送金額 > 残高 のケースでマイナスが出る
-- ------------------------------------------------------------
SELECT
  ac.user_id,
  ROUND(ac.available_usdt::numeric, 2)  AS available_usdt,
  ROUND(ac.cum_usdt::numeric, 2)        AS cum_usdt,
  ac.phase,
  ROUND(jul.total_amount::numeric, 2)   AS 七月完了額
FROM affiliate_cycle ac
LEFT JOIN monthly_withdrawals jul
       ON jul.user_id = ac.user_id
      AND jul.withdrawal_month = '2026-07-01'
      AND jul.status = 'completed'
WHERE ac.available_usdt < -0.01
ORDER BY ac.available_usdt;


-- ------------------------------------------------------------
-- 【3】7月分に未完了が残っていないか
--   pending が残っていると 8月分の修正スクリプトが例外で止まる（正しい挙動）
--   on_hold は繰越として残るのが正常
-- ------------------------------------------------------------
SELECT
  status,
  COUNT(*)                              AS 件数,
  ROUND(SUM(total_amount)::numeric, 2)  AS 合計額
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-07-01'
  AND status IN ('pending', 'on_hold')
GROUP BY status;


-- ------------------------------------------------------------
-- 【4】8月分の現状（まだ未修正のはず）
--   本体: 修正前 434件 $30,222.63
--   → 修正後の見込み = $30,222.63 − 実際に完了した額
-- ------------------------------------------------------------
SELECT
  status,
  COUNT(*)                              AS 件数,
  ROUND(SUM(total_amount)::numeric, 2)  AS 合計額
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-08-01'
GROUP BY status
ORDER BY status;

-- 8月分レコード合計 と 対象者の available_usdt 合計の一致確認
-- （完了処理後も一致していれば、上書き方式がそのまま使える）
SELECT
  (SELECT ROUND(SUM(total_amount)::numeric, 2)
     FROM monthly_withdrawals WHERE withdrawal_month = '2026-08-01')   AS 八月レコード合計,
  (SELECT ROUND(SUM(GREATEST(0, ac.available_usdt))::numeric, 2)
     FROM affiliate_cycle ac
     WHERE EXISTS (SELECT 1 FROM monthly_withdrawals mw
                    WHERE mw.user_id = ac.user_id
                      AND mw.withdrawal_month = '2026-08-01'))          AS 対象者残高合計,
  (SELECT ROUND(SUM(total_amount)::numeric, 2)
     FROM monthly_withdrawals
     WHERE withdrawal_month = '2026-07-01' AND status = 'completed')    AS 七月完了額;
-- 期待: 八月レコード合計 − 七月完了額 ≒ 対象者残高合計


-- ------------------------------------------------------------
-- 【5】9月の日利がまだ入っていないことの再確認
--   （入っていると修正スクリプトが使えない）
-- ------------------------------------------------------------
SELECT COUNT(*) AS 九月日利件数,
       ROUND(COALESCE(SUM(daily_profit), 0)::numeric, 2) AS 九月日利合計
FROM nft_daily_profit
WHERE date >= '2026-09-01';
