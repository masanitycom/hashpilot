-- ============================================================
-- 7月分未完了 × 8月分レコード既作成 の突き合わせ
-- 実行日: 2026-09-02
--
-- 判明済み:
--   - complete_withdrawals_batch は減算版（正常）
--   - 8月の紹介報酬月末処理は実施済み（2026-08: 1,144件 / $3,762.66）
--   - 9月の日利は未投入（0件）→ 今の available_usdt は 8/31時点と同じ
--   - 8月分レコードは既に作成済み（434件 / $30,222.63）＝7月分が混入
-- ============================================================


-- ------------------------------------------------------------
-- 【A】ユーザー別 7月 vs 8月 突き合わせ
--   8月修正後見込 = 8月total - 7月total（7月分を実送金済みの場合）
--   マイナスになる人は要注意（8月の利益が7月出金額より小さいケース）
-- ------------------------------------------------------------
SELECT
  COALESCE(jul.user_id, aug.user_id)                      AS user_id,
  jul.status                                              AS 七月status,
  ROUND(jul.total_amount::numeric, 2)                     AS 七月total,
  aug.status                                              AS 八月status,
  ROUND(aug.total_amount::numeric, 2)                     AS 八月total,
  ROUND(aug.personal_amount::numeric, 2)                  AS 八月個人,
  ROUND(aug.referral_amount::numeric, 2)                  AS 八月紹介,
  ROUND((aug.total_amount - COALESCE(jul.total_amount,0))::numeric, 2) AS 八月修正後見込,
  ROUND(ac.available_usdt::numeric, 2)                    AS 現在残高
FROM (SELECT * FROM monthly_withdrawals WHERE withdrawal_month = '2026-07-01') jul
FULL OUTER JOIN (SELECT * FROM monthly_withdrawals WHERE withdrawal_month = '2026-08-01') aug
  ON jul.user_id = aug.user_id
LEFT JOIN affiliate_cycle ac ON ac.user_id = COALESCE(jul.user_id, aug.user_id)
ORDER BY (aug.total_amount - COALESCE(jul.total_amount,0)) ASC
LIMIT 50;


-- ------------------------------------------------------------
-- 【B】ステータス組み合わせ別のサマリ
--   7月pending → 8月に何件・いくら乗っているか等を俯瞰する
-- ------------------------------------------------------------
SELECT
  COALESCE(jul.status, '(7月なし)')                    AS 七月status,
  COALESCE(aug.status, '(8月なし)')                    AS 八月status,
  COUNT(*)                                             AS 件数,
  ROUND(SUM(COALESCE(jul.total_amount,0))::numeric, 2) AS 七月合計,
  ROUND(SUM(COALESCE(aug.total_amount,0))::numeric, 2) AS 八月合計,
  ROUND(SUM(COALESCE(aug.total_amount,0) - COALESCE(jul.total_amount,0))::numeric, 2) AS 差額
FROM (SELECT * FROM monthly_withdrawals WHERE withdrawal_month = '2026-07-01') jul
FULL OUTER JOIN (SELECT * FROM monthly_withdrawals WHERE withdrawal_month = '2026-08-01') aug
  ON jul.user_id = aug.user_id
GROUP BY 1, 2
ORDER BY 1, 2;


-- ------------------------------------------------------------
-- 【C】available_usdt の総額と、7月+8月レコードの整合確認
--   期待: SUM(available_usdt) ≒ 8月分 total 合計（= 7月未減算分を含む）
-- ------------------------------------------------------------
SELECT
  ROUND(SUM(ac.available_usdt)::numeric, 2) AS 全ユーザー残高合計
FROM affiliate_cycle ac;

SELECT
  ROUND(SUM(total_amount)::numeric, 2) AS 八月レコード合計
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-08-01';


-- ------------------------------------------------------------
-- 【D】8月分レコードの作成日時（いつ month-end が走ったか）
-- ------------------------------------------------------------
SELECT
  MIN(created_at) AS 最初,
  MAX(created_at) AS 最後,
  COUNT(*)        AS 件数
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-08-01';


-- ------------------------------------------------------------
-- 【E】8月分のタスク完了状況（作り直した場合に影響を受ける人）
-- ------------------------------------------------------------
SELECT
  status,
  task_completed,
  COUNT(*) AS 件数
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-08-01'
GROUP BY status, task_completed
ORDER BY status, task_completed;


-- ============================================================
-- 【F】★7月分の完了処理が終わった直後に流す★
--   完了した合計額が「8月頭にCoinWから実際に送金した額」と一致するか。
--   ここがズレていると8月分の修正額もズレる。
--
--   注意: on_hold はタスク未完了ユーザー＝通常は送金対象外。
--   もし on_hold 分も実送金していた場合は、その分も完了処理が必要。
-- ============================================================
SELECT
  status,
  COUNT(*)                              AS 件数,
  ROUND(SUM(total_amount)::numeric, 2)  AS 合計額
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-07-01'
GROUP BY status
ORDER BY status;

-- 完了処理の結果、available_usdt がマイナスになった人
SELECT user_id, ROUND(available_usdt::numeric, 2) AS available_usdt,
       ROUND(cum_usdt::numeric, 2) AS cum_usdt, phase
FROM affiliate_cycle
WHERE available_usdt < -0.01
ORDER BY available_usdt;

-- withdrawn_referral_usdt に7月分が反映されたか（抜き取り）
SELECT
  ac.user_id, ac.phase,
  ROUND(ac.cum_usdt::numeric, 2)                AS cum_usdt,
  ROUND(ac.withdrawn_referral_usdt::numeric, 2) AS withdrawn_referral_usdt,
  ROUND(jul.referral_amount::numeric, 2)        AS 七月紹介報酬
FROM affiliate_cycle ac
JOIN monthly_withdrawals jul
  ON jul.user_id = ac.user_id AND jul.withdrawal_month = '2026-07-01'
WHERE COALESCE(jul.referral_amount, 0) > 0
ORDER BY jul.referral_amount DESC
LIMIT 20;
