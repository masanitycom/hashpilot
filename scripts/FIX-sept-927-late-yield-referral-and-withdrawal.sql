-- ============================================================
-- 9/27の日利が月末処理の後に入力された件の修正（本サイト）
--
-- 経緯:
--   10/01 08:23 UTC  9/30の日利入力 → 月末処理が自動実行
--                    （9月の紹介報酬・出金レコードを作成）
--   10/02 03:31 UTC  9/27の日利を後から入力（948枚、計 533.72ドル）
--   → 9月の紹介報酬と出金レコードに 9/27分が入っていない
--
-- 修正内容:
--   A. 9月の紹介報酬を 9/27込みの月間合計で再計算（差額のみ加算）
--      monthly_referral_profit / affiliate_cycle.cum_usdt / available_usdt / phase
--   B. 9月の出金レコードに「9/27の日利」と「紹介報酬の差額」を上乗せ
--
-- 方式: 差額のみを加算する。
--   process_monthly_referral_reward(…, p_overwrite => true) は使わない
--   （cum_usdt に9月分が丸ごと二重加算されるため）。
--   出金レコードは作り直さない（タスク完了済みユーザーが on_hold で詰むため）。
--   10月の日利が既に入っているので、available_usdt での上書きもしない。
--
-- 想定値（2026-10-03 調査時点）:
--   紹介報酬の差額 : 190名 合計 約178.47ドル
--   9/27の日利     : 出金レコードのある人の合計 約532.88ドル
--
-- 二重実行防止: 作業テーブルが既にあると CREATE TABLE でエラーになり全体が取り消される
-- ============================================================

BEGIN;

-- ============================================================
-- STEP 1: バックアップ
-- ============================================================
CREATE TABLE backup_monthly_withdrawals_202609_before927 AS
SELECT * FROM monthly_withdrawals WHERE withdrawal_month = '2026-09-01';

CREATE TABLE backup_monthly_referral_profit_202609_before927 AS
SELECT * FROM monthly_referral_profit WHERE year_month = '2026-09';

CREATE TABLE backup_affiliate_cycle_20261003_before927 AS
SELECT * FROM affiliate_cycle;


-- ============================================================
-- STEP 2: 差額の計算（作業テーブル。記録として残す）
-- ============================================================
-- 2-1) 紹介報酬の行ごとの正しい金額
CREATE TABLE fix_sept927_mrp_delta AS
WITH sep AS (
  SELECT user_id, SUM(daily_profit) AS sep_profit
  FROM nft_daily_profit
  WHERE date >= '2026-09-01' AND date <= '2026-09-30'
  GROUP BY user_id
)
SELECT
  mrp.id,
  mrp.user_id,
  mrp.profit_amount AS old_amount,
  GREATEST(0, sep.sep_profit) * CASE mrp.referral_level
    WHEN 1 THEN 0.20 WHEN 2 THEN 0.10 WHEN 3 THEN 0.05 END AS new_amount
FROM monthly_referral_profit mrp
JOIN sep ON sep.user_id = mrp.child_user_id
WHERE mrp.year_month = '2026-09';

-- 2-2) ユーザーごとの差額と、出金可能額の増加分
--   出金可能額の増加 = LEAST(新cum, 1100) − LEAST(旧cum, 1100)
--   （process_monthly_referral_reward の STEP 8 と同じ考え方。HOLD分は増えない）
CREATE TABLE fix_sept927_user_delta AS
WITH d AS (
  SELECT user_id, SUM(new_amount - old_amount) AS ref_delta
  FROM fix_sept927_mrp_delta
  GROUP BY user_id
  HAVING ABS(SUM(new_amount - old_amount)) > 0.000001
)
SELECT
  d.user_id,
  d.ref_delta,
  ac.cum_usdt AS old_cum,
  ac.cum_usdt + d.ref_delta AS new_cum,
  GREATEST(0, LEAST(ac.cum_usdt + d.ref_delta, 1100) - LEAST(ac.cum_usdt, 1100)) AS payout_delta,
  ac.phase AS old_phase,
  ac.available_usdt AS old_available
FROM d
LEFT JOIN affiliate_cycle ac ON ac.user_id = d.user_id;


-- ============================================================
-- STEP 3: 前提チェック（満たさなければ全体を取り消して停止）
-- ============================================================
DO $$
DECLARE
  v_completed  INTEGER;
  v_no_cycle   INTEGER;
  v_negative   INTEGER;
  v_nft_users  TEXT;
BEGIN
  -- 9月分が既に送金完了になっていたら止める
  SELECT COUNT(*) INTO v_completed
  FROM monthly_withdrawals
  WHERE withdrawal_month = '2026-09-01' AND status = 'completed';
  IF v_completed > 0 THEN
    RAISE EXCEPTION '9月分に送金完了済みのレコードが%件あります。このスクリプトは使えません（要相談）。', v_completed;
  END IF;

  -- affiliate_cycle が無い受給者
  SELECT COUNT(*) INTO v_no_cycle FROM fix_sept927_user_delta WHERE old_cum IS NULL;
  IF v_no_cycle > 0 THEN
    RAISE EXCEPTION 'affiliate_cycle が無い受給者が%名います（要調査）。', v_no_cycle;
  END IF;

  -- 差額がマイナス（想定外）
  SELECT COUNT(*) INTO v_negative FROM fix_sept927_user_delta WHERE ref_delta < -0.001;
  IF v_negative > 0 THEN
    RAISE EXCEPTION '紹介報酬の差額がマイナスになるユーザーが%名います（要調査）。', v_negative;
  END IF;

  -- 差額の加算で 2200 に到達（NFT自動付与が必要）→ 個別対応
  SELECT string_agg(user_id, ', ') INTO v_nft_users
  FROM fix_sept927_user_delta WHERE new_cum >= 2200;
  IF v_nft_users IS NOT NULL THEN
    RAISE EXCEPTION '差額の加算で cum_usdt が2200以上になるユーザーがいます: %（NFT自動付与が絡むため個別対応）', v_nft_users;
  END IF;
END $$;


-- ============================================================
-- STEP 4: 紹介報酬の修正
-- ============================================================
-- 4-1) 紹介報酬の明細
UPDATE monthly_referral_profit mrp
SET profit_amount = x.new_amount
FROM fix_sept927_mrp_delta x
WHERE mrp.id = x.id
  AND ABS(x.new_amount - x.old_amount) > 0.000001;

-- 4-2) 紹介報酬累計・出金可能額・フェーズ
UPDATE affiliate_cycle ac
SET cum_usdt = x.new_cum,
    available_usdt = ac.available_usdt + x.payout_delta,
    phase = CASE WHEN x.new_cum < 1100 THEN 'USDT' ELSE 'HOLD' END,
    updated_at = NOW()
FROM fix_sept927_user_delta x
WHERE ac.user_id = x.user_id;


-- ============================================================
-- STEP 5: 9月の出金レコードに上乗せ
--   total    += 9/27の日利 + 紹介報酬の出金可能増加分
--   personal += 9/27の日利
--   referral += 紹介報酬の出金可能増加分
-- ============================================================
WITH d927 AS (
  SELECT user_id, SUM(daily_profit) AS amt
  FROM nft_daily_profit
  WHERE date = '2026-09-27'
  GROUP BY user_id
),
x AS (
  SELECT
    mw.id,
    COALESCE(d927.amt, 0) AS add_personal,
    COALESCE(u.payout_delta, 0) AS add_referral
  FROM monthly_withdrawals mw
  LEFT JOIN d927 ON d927.user_id = mw.user_id
  LEFT JOIN fix_sept927_user_delta u ON u.user_id = mw.user_id
  WHERE mw.withdrawal_month = '2026-09-01'
    AND mw.status IN ('pending', 'on_hold')
)
UPDATE monthly_withdrawals mw
SET total_amount    = ROUND((mw.total_amount + x.add_personal + x.add_referral)::numeric, 2),
    personal_amount = ROUND((COALESCE(mw.personal_amount, 0) + x.add_personal)::numeric, 2),
    referral_amount = ROUND((COALESCE(mw.referral_amount, 0) + x.add_referral)::numeric, 2),
    notes = COALESCE(NULLIF(mw.notes, ''), '')
            || CASE WHEN COALESCE(mw.notes, '') <> '' THEN ' | ' ELSE '' END
            || '2026-10-03 9/27日利の後入力分を反映（修正前 '
            || ROUND(mw.total_amount::numeric, 2) || '）',
    updated_at = NOW()
FROM x
WHERE mw.id = x.id
  AND (ABS(x.add_personal) > 0.000001 OR ABS(x.add_referral) > 0.000001);

COMMIT;


-- ============================================================
-- STEP 6: 検証
-- ============================================================
-- 6-1) 紹介報酬: 修正人数と合計（想定 190名 / 約178.47）
SELECT
  COUNT(*) AS 修正人数,
  ROUND(SUM(ref_delta)::numeric, 2) AS 紹介報酬の追加合計,
  ROUND(SUM(payout_delta)::numeric, 2) AS うち出金可能になった額,
  COUNT(*) FILTER (WHERE new_cum >= 1100) AS HOLDフェーズの人数
FROM fix_sept927_user_delta;

-- 6-2) 出金レコード: 修正前後の合計
SELECT
  (SELECT ROUND(SUM(total_amount)::numeric, 2) FROM backup_monthly_withdrawals_202609_before927) AS 修正前の出金合計,
  ROUND(SUM(total_amount)::numeric, 2) AS 修正後の出金合計,
  ROUND(SUM(personal_amount)::numeric, 2) AS 修正後の個人利益合計,
  ROUND(SUM(referral_amount)::numeric, 2) AS 修正後の紹介報酬合計
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-09-01';

-- 6-3) 出金レコードと残高の突き合わせ
--   「現在の残高 − 10月の日利」が出金合計と一致するはず。
--   ここに出るユーザーは個別確認（既知の残高ズレユーザーは出る可能性あり）
WITH oct AS (
  SELECT user_id, SUM(daily_profit) AS amt
  FROM nft_daily_profit
  WHERE date >= '2026-10-01'
  GROUP BY user_id
)
SELECT
  mw.user_id,
  mw.status,
  mw.total_amount AS 出金合計,
  ROUND((ac.available_usdt - COALESCE(oct.amt, 0))::numeric, 2) AS 九月末時点の残高,
  ROUND((mw.total_amount - (ac.available_usdt - COALESCE(oct.amt, 0)))::numeric, 2) AS 差
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON ac.user_id = mw.user_id
LEFT JOIN oct ON oct.user_id = mw.user_id
WHERE mw.withdrawal_month = '2026-09-01'
  AND ABS(mw.total_amount - (ac.available_usdt - COALESCE(oct.amt, 0))) > 0.05
ORDER BY ABS(mw.total_amount - (ac.available_usdt - COALESCE(oct.amt, 0))) DESC;

-- 6-4) 紹介報酬の不足が残っていないか（0件ならOK）
WITH sep AS (
  SELECT user_id, SUM(daily_profit) AS sep_profit
  FROM nft_daily_profit
  WHERE date >= '2026-09-01' AND date <= '2026-09-30'
  GROUP BY user_id
)
SELECT COUNT(*) AS 不足が残っている行数
FROM monthly_referral_profit mrp
JOIN sep ON sep.user_id = mrp.child_user_id
WHERE mrp.year_month = '2026-09'
  AND ABS(mrp.profit_amount - GREATEST(0, sep.sep_profit) * CASE mrp.referral_level
        WHEN 1 THEN 0.20 WHEN 2 THEN 0.10 WHEN 3 THEN 0.05 END) > 0.001;


-- ============================================================
-- 【ロールバック】取り消す場合（上から順に実行）
-- ============================================================
-- UPDATE monthly_withdrawals mw
-- SET total_amount = b.total_amount, personal_amount = b.personal_amount,
--     referral_amount = b.referral_amount, notes = b.notes, updated_at = NOW()
-- FROM backup_monthly_withdrawals_202609_before927 b
-- WHERE mw.id = b.id;
--
-- UPDATE monthly_referral_profit mrp
-- SET profit_amount = b.profit_amount
-- FROM backup_monthly_referral_profit_202609_before927 b
-- WHERE mrp.id = b.id;
--
-- UPDATE affiliate_cycle ac
-- SET cum_usdt = ac.cum_usdt - x.ref_delta,
--     available_usdt = ac.available_usdt - x.payout_delta,
--     phase = x.old_phase, updated_at = NOW()
-- FROM fix_sept927_user_delta x
-- WHERE ac.user_id = x.user_id;
--
-- DROP TABLE fix_sept927_mrp_delta;
-- DROP TABLE fix_sept927_user_delta;
