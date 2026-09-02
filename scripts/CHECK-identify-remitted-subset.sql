-- ============================================================
-- 「実際に送金したレコード」を金額から特定する
--
-- 本体(HASHPILOT)   : 2026-07-01 分 / 実送金 $14,786.89
--                     （全434件=$15,943.59、pendingのみ=$9,524.16 のどちらとも不一致）
-- サブ(HASHPILOT_COPY): 2026-07-01 分 / 実送金 $172.75
--
-- ※ 対象月は下の v_month を書き換えて使う
-- ============================================================

-- ------------------------------------------------------------
-- 【1】ステータス別（基準値の確認）
-- ------------------------------------------------------------
SELECT status, COUNT(*) AS 件数, ROUND(SUM(total_amount)::numeric, 2) AS 合計
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-07-01'
GROUP BY ROLLUP(status)
ORDER BY status NULLS LAST;


-- ------------------------------------------------------------
-- 【2】仮説A: 少額（CoinW最低出金額未満）を除外して送金した
--   閾値ごとの送金額を出し、$14,786.89 に一致するものを探す
-- ------------------------------------------------------------
SELECT
  t.threshold                                                        AS 閾値,
  COUNT(*) FILTER (WHERE mw.total_amount >= t.threshold)              AS 送金件数,
  ROUND(SUM(mw.total_amount) FILTER (WHERE mw.total_amount >= t.threshold)::numeric, 2) AS 送金額,
  COUNT(*) FILTER (WHERE mw.total_amount < t.threshold)               AS 除外件数,
  ROUND(SUM(mw.total_amount) FILTER (WHERE mw.total_amount < t.threshold)::numeric, 2)  AS 除外額
FROM monthly_withdrawals mw
CROSS JOIN (VALUES (0.5),(1),(2),(2.2),(2.5),(3),(5),(10),(11),(11.25),(15),(20)) AS t(threshold)
WHERE mw.withdrawal_month = '2026-07-01'
GROUP BY t.threshold
ORDER BY t.threshold;


-- ------------------------------------------------------------
-- 【3】仮説B: 送金先が未設定・未確認のユーザーを除外した
-- ------------------------------------------------------------
SELECT
  CASE
    WHEN mw.withdrawal_address IS NULL OR mw.withdrawal_address = '' THEN '送金先なし'
    WHEN u.coinw_uid IS NULL OR u.coinw_uid = ''                     THEN 'CoinW UIDなし'
    WHEN COALESCE(u.channel_linked_confirmed, false) = false          THEN 'CH紐付け未確認'
    ELSE '送金可能'
  END                                   AS 区分,
  COUNT(*)                              AS 件数,
  ROUND(SUM(mw.total_amount)::numeric, 2) AS 合計
FROM monthly_withdrawals mw
JOIN users u ON u.user_id = mw.user_id
WHERE mw.withdrawal_month = '2026-07-01'
GROUP BY 1
ORDER BY 3 DESC;


-- ------------------------------------------------------------
-- 【4】仮説C: 完了済み（completed）が既に一部ある／notesに繰越記載がある
-- ------------------------------------------------------------
SELECT
  COALESCE(NULLIF(notes, ''), '(なし)')  AS notes,
  COUNT(*)                               AS 件数,
  ROUND(SUM(total_amount)::numeric, 2)   AS 合計
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-07-01'
GROUP BY 1
ORDER BY 2 DESC
LIMIT 20;


-- ------------------------------------------------------------
-- 【5】差額 $1,156.70 に該当しそうなレコードを探す
--   （全434件 $15,943.59 − 実送金 $14,786.89 = $1,156.70）
--   少額から積み上げてどこで $1,156.70 になるか
-- ------------------------------------------------------------
WITH ranked AS (
  SELECT
    user_id, status, total_amount,
    SUM(total_amount) OVER (ORDER BY total_amount, user_id
                            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS 累計,
    ROW_NUMBER()      OVER (ORDER BY total_amount, user_id)                   AS 順位
  FROM monthly_withdrawals
  WHERE withdrawal_month = '2026-07-01'
)
SELECT * FROM ranked
WHERE 累計 <= 1300
ORDER BY 累計;


-- ------------------------------------------------------------
-- 【6】最終確認: 事務の送金リスト(CSV)と突き合わせる用の一覧
--   これをCSVに出して、事務のCoinW送金実績と1件ずつ突き合わせるのが確実
-- ------------------------------------------------------------
SELECT
  mw.user_id,
  u.email,
  mw.status,
  mw.withdrawal_method,
  mw.withdrawal_address,
  ROUND(mw.total_amount::numeric, 2)    AS 出金額,
  ROUND(mw.personal_amount::numeric, 2) AS 個人利益,
  ROUND(mw.referral_amount::numeric, 2) AS 紹介報酬
FROM monthly_withdrawals mw
JOIN users u ON u.user_id = mw.user_id
WHERE mw.withdrawal_month = '2026-07-01'
ORDER BY mw.total_amount DESC;
